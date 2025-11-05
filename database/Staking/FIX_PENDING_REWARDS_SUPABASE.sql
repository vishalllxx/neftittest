-- =============================================================================
-- FIX PENDING REWARDS - SUPABASE COMPATIBLE VERSION
-- =============================================================================
-- Run this script in Supabase SQL Editor
-- Replace YOUR_WALLET_ADDRESS with your actual wallet address
-- =============================================================================

-- =============================================================================
-- STEP 1: CHECK YOUR CURRENT STAKING STATUS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 STEP 1: CHECKING CURRENT STAKING STATUS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- Check staked NFTs (Replace YOUR_WALLET_ADDRESS)
SELECT 
    '1. Your Staked NFTs' as check_type,
    COUNT(*) as nft_count,
    SUM(daily_reward) as total_daily_nft_rewards,
    STRING_AGG(nft_rarity, ', ') as rarities_staked
FROM staked_nfts 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- Check staked tokens
SELECT 
    '2. Your Staked Tokens' as check_type,
    COUNT(*) as positions_count,
    SUM(amount) as total_staked_tokens,
    SUM(daily_reward) as total_daily_token_rewards
FROM staked_tokens 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- =============================================================================
-- STEP 2: CHECK REWARDS TABLE STATUS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 STEP 2: CHECKING REWARDS TABLE';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- Check if any rewards exist in database
SELECT 
    '3. Rewards Table Status' as check_type,
    COUNT(*) as total_records,
    COUNT(DISTINCT wallet_address) as unique_wallets,
    MAX(reward_date) as latest_reward_date,
    COUNT(*) FILTER (WHERE is_claimed = false) as unclaimed_records
FROM staking_rewards;

-- Check YOUR specific wallet rewards
SELECT 
    '4. Your Rewards History' as check_type,
    reward_date,
    nft_earned_today,
    token_earned_today,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY reward_date DESC
LIMIT 10;

-- Check YOUR pending rewards
SELECT 
    '5. Your Pending Rewards' as check_type,
    COALESCE(SUM(nft_earned_today), 0) as pending_nft_rewards,
    COALESCE(SUM(token_earned_today), 0) as pending_token_rewards,
    COALESCE(SUM(nft_earned_today + token_earned_today), 0) as total_pending_rewards,
    COUNT(*) as unclaimed_days
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071' 
  AND is_claimed = false;

-- =============================================================================
-- STEP 3: CHECK CRON JOB STATUS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 STEP 3: CHECKING CRON JOB STATUS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- Check if pg_cron extension is enabled
SELECT 
    '6. pg_cron Extension' as check_type,
    CASE 
        WHEN EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
        THEN '✅ ENABLED'
        ELSE '❌ NOT ENABLED'
    END as status;

-- Check if cron job exists
SELECT 
    '7. Cron Job Status' as check_type,
    jobid,
    jobname,
    schedule,
    active,
    CASE 
        WHEN active THEN '✅ ACTIVE'
        ELSE '❌ INACTIVE'
    END as status
FROM cron.job 
WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
ORDER BY jobid DESC;

-- =============================================================================
-- STEP 4: MANUAL FIX - GENERATE REWARDS NOW
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 STEP 4: MANUALLY GENERATING REWARDS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '⚡ Generating rewards for all staked users...';
END $$;

-- Run the reward generation function
SELECT 
    'Manual Generation Result' as action,
    generate_daily_staking_rewards() as result;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Manual reward generation completed!';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 5: VERIFY REWARDS WERE GENERATED
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 STEP 5: VERIFYING REWARDS WERE GENERATED';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- Check if rewards were created today
SELECT 
    '8. After Manual Generation' as check_type,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE reward_date = CURRENT_DATE) as todays_records,
    COUNT(*) FILTER (WHERE is_claimed = false) as unclaimed_records
FROM staking_rewards;

-- Check YOUR specific rewards again
SELECT 
    '9. Your Updated Rewards' as check_type,
    reward_date,
    nft_earned_today,
    token_earned_today,
    (nft_earned_today + token_earned_today) as total_today,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY reward_date DESC
LIMIT 5;

-- Test the summary function
SELECT 
    '10. Summary Function Test' as check_type,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as your_summary;

-- =============================================================================
-- STEP 6: SETUP AUTOMATIC CRON JOB
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '⚙️  STEP 6: SETTING UP AUTOMATIC CRON JOB';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove any existing staking reward cron jobs
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid, jobname FROM cron.job 
        WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
        RAISE NOTICE 'Removed existing cron job: % (ID: %)', job_record.jobname, job_record.jobid;
    END LOOP;
END $$;

-- Create new cron job (runs every 6 hours)
SELECT cron.schedule(
    'generate-staking-rewards-6h',
    '0 */6 * * *',  -- Every 6 hours at minute 0 (00:00, 06:00, 12:00, 18:00 UTC)
    $$SELECT generate_daily_staking_rewards();$$
) as cron_job_id;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Cron job created successfully!';
    RAISE NOTICE '   Schedule: Every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)';
    RAISE NOTICE '';
END $$;

-- Verify cron job was created
SELECT 
    '11. New Cron Job Verified' as check_type,
    jobid,
    jobname,
    schedule,
    active,
    CASE 
        WHEN active THEN '✅ ACTIVE'
        ELSE '❌ INACTIVE'
    END as status
FROM cron.job 
WHERE jobname = 'generate-staking-rewards-6h';

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO postgres;
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO anon;

-- =============================================================================
-- STEP 7: FINAL STATUS REPORT
-- =============================================================================

DO $$
DECLARE
    rewards_count INTEGER;
    pending_amount DECIMAL;
    cron_active BOOLEAN;
    function_exists BOOLEAN;
    wallet_addr TEXT := '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
BEGIN
    -- Check rewards table
    SELECT COUNT(*) INTO rewards_count 
    FROM staking_rewards 
    WHERE wallet_address = wallet_addr;
    
    -- Check pending rewards
    SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0) INTO pending_amount
    FROM staking_rewards 
    WHERE wallet_address = wallet_addr AND is_claimed = false;
    
    -- Check cron job
    SELECT EXISTS(
        SELECT 1 FROM cron.job 
        WHERE jobname = 'generate-staking-rewards-6h' AND active = true
    ) INTO cron_active;
    
    -- Check function
    SELECT EXISTS(
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'generate_daily_staking_rewards'
    ) INTO function_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ FINAL STATUS REPORT';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📋 System Status:';
    RAISE NOTICE '   • Reward Function: %', CASE WHEN function_exists THEN '✅ EXISTS' ELSE '❌ MISSING' END;
    RAISE NOTICE '   • Cron Job: %', CASE WHEN cron_active THEN '✅ ACTIVE' ELSE '❌ INACTIVE' END;
    RAISE NOTICE '   • Your Reward Records: %', rewards_count;
    RAISE NOTICE '   • Your Pending Rewards: % NEFT', pending_amount;
    RAISE NOTICE '';
    RAISE NOTICE '⚡ What Was Done:';
    RAISE NOTICE '   1. ✅ Checked staking status';
    RAISE NOTICE '   2. ✅ Verified rewards table';
    RAISE NOTICE '   3. ✅ Manually generated rewards';
    RAISE NOTICE '   4. ✅ Setup automatic cron job (every 6 hours)';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Automatic Operation:';
    RAISE NOTICE '   • Rewards auto-generate every 6 hours';
    RAISE NOTICE '   • Next run: Next 6-hour mark (00:00, 06:00, 12:00, 18:00 UTC)';
    RAISE NOTICE '   • Monitor: SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT STEPS:';
    RAISE NOTICE '   1. Refresh your staking page UI';
    RAISE NOTICE '   2. Pending rewards should now show: % NEFT', pending_amount;
    RAISE NOTICE '   3. Claim button should be %', CASE WHEN pending_amount > 0.01 THEN 'ENABLED ✅' ELSE 'disabled (no rewards yet)' END;
    RAISE NOTICE '';
    
    IF pending_amount = 0 THEN
        RAISE NOTICE '⚠️  WARNING: Pending rewards are still 0!';
        RAISE NOTICE '   Possible reasons:';
        RAISE NOTICE '   • No assets staked in database';
        RAISE NOTICE '   • Wallet address mismatch (check case sensitivity)';
        RAISE NOTICE '   • Reward generation function failed';
        RAISE NOTICE '';
        RAISE NOTICE '   Debug steps:';
        RAISE NOTICE '   1. Verify wallet address is correct';
        RAISE NOTICE '   2. Check staked_nfts and staked_tokens tables';
        RAISE NOTICE '   3. Review error messages above';
    ELSE
        RAISE NOTICE '🎉 SUCCESS! Your staking rewards system is operational!';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
END $$;

-- =============================================================================
-- ADDITIONAL MONITORING QUERIES
-- =============================================================================

-- View cron job execution history
SELECT 
    'Cron Execution History' as info,
    j.jobname,
    jrd.status,
    jrd.return_message,
    jrd.start_time,
    jrd.end_time
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.jobname = 'generate-staking-rewards-6h'
ORDER BY jrd.start_time DESC 
LIMIT 5;

-- =============================================================================
-- MANUAL COMMANDS FOR FUTURE USE
-- =============================================================================

-- To manually generate rewards anytime:
-- SELECT generate_daily_staking_rewards();

-- To check your summary anytime:
-- SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- To view all cron jobs:
-- SELECT * FROM cron.job;

-- To view cron job history:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;

-- To remove cron job if needed:
-- SELECT cron.unschedule('generate-staking-rewards-6h');
