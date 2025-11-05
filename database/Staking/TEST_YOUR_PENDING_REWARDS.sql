-- ============================================================================
-- DIAGNOSE YOUR 12-DAY STAKING REWARDS ISSUE
-- Run this script in Supabase SQL Editor
-- ============================================================================

-- STEP 1: Check if generate_daily_staking_rewards function exists
-- ============================================================================
DO $$
DECLARE
    func_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'generate_daily_staking_rewards'
    ) INTO func_exists;
    
    IF func_exists THEN
        RAISE NOTICE '✅ Function generate_daily_staking_rewards EXISTS';
    ELSE
        RAISE NOTICE '❌ Function generate_daily_staking_rewards DOES NOT EXIST!';
        RAISE NOTICE '   → You need to deploy FIX_02_REWARD_GENERATION_FINAL.sql first';
    END IF;
END $$;

-- STEP 2: Check your staked assets (replace with your wallet address)
-- ============================================================================
-- 🔧 REPLACE THIS WITH YOUR WALLET ADDRESS:
-- \set MY_WALLET 'YOUR_WALLET_ADDRESS_HERE'

-- For now, let's check all wallets:
SELECT 
    '🎨 STAKED NFTs' as asset_type,
    wallet_address,
    COUNT(*) as count,
    SUM(daily_reward) as total_daily_reward,
    MIN(staked_at) as first_staked,
    MAX(staked_at) as last_staked,
    EXTRACT(DAYS FROM (NOW() - MIN(staked_at))) as days_staked
FROM staked_nfts
GROUP BY wallet_address;

SELECT 
    '🪙 STAKED TOKENS' as asset_type,
    wallet_address,
    SUM(amount) as total_staked,
    SUM(daily_reward) as total_daily_reward,
    MIN(staked_at) as first_staked,
    MAX(staked_at) as last_staked,
    EXTRACT(DAYS FROM (NOW() - MIN(staked_at))) as days_staked
FROM staked_tokens
GROUP BY wallet_address;

-- STEP 3: Check existing rewards in staking_rewards table
-- ============================================================================
SELECT 
    '💰 EXISTING REWARDS' as check_type,
    wallet_address,
    COUNT(*) as reward_records,
    MIN(reward_date) as first_reward,
    MAX(reward_date) as last_reward,
    SUM(COALESCE(nft_rewards, 0) + COALESCE(token_rewards, 0)) as total_rewards_generated,
    SUM(CASE WHEN is_claimed THEN COALESCE(nft_rewards, 0) + COALESCE(token_rewards, 0) ELSE 0 END) as total_claimed
FROM staking_rewards
GROUP BY wallet_address;

-- STEP 4: Check if cron job exists
-- ============================================================================
SELECT 
    '⏰ CRON JOB STATUS' as status_type,
    jobid,
    jobname,
    schedule,
    active,
    command
FROM cron.job 
WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
ORDER BY jobid;

-- Check recent cron execution
SELECT 
    '📊 RECENT CRON RUNS' as status_type,
    j.jobname,
    jrd.status,
    jrd.return_message,
    jrd.start_time,
    jrd.end_time
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.jobname LIKE '%staking%' OR j.jobname LIKE '%reward%'
ORDER BY jrd.start_time DESC
LIMIT 5;

-- STEP 5: Calculate what rewards SHOULD BE (expected vs actual)
-- ============================================================================
WITH expected_rewards AS (
    SELECT 
        wallet_address,
        SUM(daily_reward) as daily_nft_reward,
        EXTRACT(DAYS FROM (NOW() - MIN(staked_at)))::INTEGER as days_staked,
        SUM(daily_reward) * EXTRACT(DAYS FROM (NOW() - MIN(staked_at)))::INTEGER as expected_total
    FROM staked_nfts
    GROUP BY wallet_address
),
actual_rewards AS (
    SELECT 
        wallet_address,
        SUM(COALESCE(nft_rewards, 0)) as actual_total
    FROM staking_rewards
    GROUP BY wallet_address
)
SELECT 
    '🔍 EXPECTED vs ACTUAL' as comparison,
    COALESCE(e.wallet_address, a.wallet_address) as wallet,
    COALESCE(e.daily_nft_reward, 0) as daily_reward,
    COALESCE(e.days_staked, 0) as days_staked,
    COALESCE(e.expected_total, 0) as expected_total_rewards,
    COALESCE(a.actual_total, 0) as actual_rewards_generated,
    COALESCE(e.expected_total, 0) - COALESCE(a.actual_total, 0) as missing_rewards
FROM expected_rewards e
FULL OUTER JOIN actual_rewards a ON e.wallet_address = a.wallet_address;

-- ============================================================================
-- IMMEDIATE FIX: Generate rewards manually
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '🚀 GENERATING REWARDS NOW...';
    RAISE NOTICE '═══════════════════════════════════════════════';
END $$;

-- Generate rewards for all users with staked assets
SELECT generate_daily_staking_rewards() as wallets_processed;

-- STEP 6: Verify rewards were generated
-- ============================================================================
SELECT 
    '✅ REWARDS AFTER GENERATION' as status,
    wallet_address,
    reward_date,
    nft_rewards,
    token_rewards,
    is_claimed,
    last_updated
FROM staking_rewards
ORDER BY wallet_address, reward_date DESC;

-- STEP 7: Check updated summary for each wallet
-- ============================================================================
-- For each wallet with staked assets, get the summary
DO $$
DECLARE
    wallet_rec RECORD;
    summary_result JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '📊 STAKING SUMMARY FOR EACH WALLET';
    RAISE NOTICE '═══════════════════════════════════════════════';
    
    FOR wallet_rec IN 
        SELECT DISTINCT wallet_address FROM staked_nfts
        UNION
        SELECT DISTINCT wallet_address FROM staked_tokens
    LOOP
        BEGIN
            SELECT get_user_staking_summary(wallet_rec.wallet_address) INTO summary_result;
            RAISE NOTICE '';
            RAISE NOTICE '👛 Wallet: %', wallet_rec.wallet_address;
            RAISE NOTICE '   Summary: %', summary_result::TEXT;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '   ❌ Error getting summary: %', SQLERRM;
        END;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 8: Setup automatic cron job (if not exists)
-- ============================================================================

-- Remove old cron jobs first
DO $$
DECLARE
    job_rec RECORD;
BEGIN
    FOR job_rec IN 
        SELECT jobname FROM cron.job 
        WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
    LOOP
        PERFORM cron.unschedule(job_rec.jobname);
        RAISE NOTICE '🗑️ Removed old job: %', job_rec.jobname;
    END LOOP;
END $$;

-- Create new cron job (runs every 6 hours)
SELECT cron.schedule(
    'daily-staking-rewards-auto',
    '0 */6 * * *',  -- Every 6 hours (0:00, 6:00, 12:00, 18:00 UTC)
    'SELECT generate_daily_staking_rewards();'
) as cron_job_id;

-- Verify new cron job
SELECT 
    '✅ NEW CRON JOB CREATED' as status,
    jobid,
    jobname,
    schedule,
    active,
    command
FROM cron.job 
WHERE jobname = 'daily-staking-rewards-auto';

-- ============================================================================
-- FINAL STATUS REPORT
-- ============================================================================
DO $$
DECLARE
    total_wallets INTEGER;
    total_staked_nfts INTEGER;
    total_staked_tokens NUMERIC;
    total_pending_rewards NUMERIC;
BEGIN
    SELECT COUNT(DISTINCT wallet_address) INTO total_wallets FROM staked_nfts;
    SELECT COUNT(*) INTO total_staked_nfts FROM staked_nfts;
    SELECT SUM(amount) INTO total_staked_tokens FROM staked_tokens;
    
    SELECT SUM(
        COALESCE(nft_rewards, 0) + COALESCE(token_rewards, 0)
    ) INTO total_pending_rewards
    FROM staking_rewards
    WHERE is_claimed = FALSE;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '📋 FINAL STATUS REPORT';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '👥 Total Wallets Staking: %', total_wallets;
    RAISE NOTICE '🎨 Total Staked NFTs: %', total_staked_nfts;
    RAISE NOTICE '🪙 Total Staked Tokens: % NEFT', COALESCE(total_staked_tokens, 0);
    RAISE NOTICE '💰 Total Pending Rewards: % NEFT', COALESCE(total_pending_rewards, 0);
    RAISE NOTICE '';
    RAISE NOTICE '✅ ACTIONS COMPLETED:';
    RAISE NOTICE '   • Generated rewards manually';
    RAISE NOTICE '   • Setup automatic cron job (every 6 hours)';
    RAISE NOTICE '   • Verified reward generation';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT STEPS:';
    RAISE NOTICE '   1. Refresh your staking page';
    RAISE NOTICE '   2. Check pending rewards in UI';
    RAISE NOTICE '   3. Claim button should now be enabled';
    RAISE NOTICE '';
    RAISE NOTICE '📌 MANUAL GENERATION:';
    RAISE NOTICE '   Run: SELECT generate_daily_staking_rewards();';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 CHECK YOUR SUMMARY:';
    RAISE NOTICE '   Run: SELECT get_user_staking_summary(''YOUR_WALLET_ADDRESS'');';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- TROUBLESHOOTING QUERIES
-- ============================================================================

-- If you still see 0 rewards, run these to diagnose:

-- 1. Check if your wallet has staked assets
-- SELECT * FROM staked_nfts WHERE wallet_address = 'YOUR_WALLET_ADDRESS';
-- SELECT * FROM staked_tokens WHERE wallet_address = 'YOUR_WALLET_ADDRESS';

-- 2. Check if rewards exist for your wallet
-- SELECT * FROM staking_rewards WHERE wallet_address = 'YOUR_WALLET_ADDRESS';

-- 3. Check the summary function output
-- SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- 4. Check daily reward calculation
-- SELECT nft_id, rarity, daily_reward FROM staked_nfts WHERE wallet_address = 'YOUR_WALLET_ADDRESS';

-- 5. Force regenerate rewards (if needed)
-- DELETE FROM staking_rewards WHERE wallet_address = 'YOUR_WALLET_ADDRESS';
-- SELECT generate_daily_staking_rewards();
