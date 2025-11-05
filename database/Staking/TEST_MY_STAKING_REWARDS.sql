-- =============================================================================
-- TEST YOUR STAKING REWARDS - PERSONALIZED TESTING
-- =============================================================================
-- This script will help you verify your specific staking setup
-- 
-- INSTRUCTIONS:
-- 1. Copy your wallet address from the staking page UI
-- 2. Replace 'YOUR_WALLET_ADDRESS' below with your actual address
-- 3. Run this entire script in Supabase SQL Editor
-- 4. Review the output to see your staking status
-- =============================================================================

-- 📋 SET YOUR WALLET ADDRESS HERE
\set wallet_address 'YOUR_WALLET_ADDRESS'

\echo ''
\echo '════════════════════════════════════════════════════════════════════════════'
\echo '🔍 TESTING STAKING REWARDS FOR YOUR WALLET'
\echo '════════════════════════════════════════════════════════════════════════════'
\echo ''

-- =============================================================================
-- TEST 1: Check Your Staked Assets
-- =============================================================================
\echo '📊 TEST 1: Your Staked Assets'
\echo '─────────────────────────────────────────────────────────────────────────'

SELECT 
    'NFTs Staked' as asset_type,
    COUNT(*) as count,
    COALESCE(SUM(daily_reward), 0) as daily_rewards_total,
    STRING_AGG(nft_rarity, ', ') as rarities
FROM staked_nfts 
WHERE wallet_address = :'wallet_address'
UNION ALL
SELECT 
    'Tokens Staked' as asset_type,
    COUNT(*) as count,
    COALESCE(SUM(daily_reward), 0) as daily_rewards_total,
    CONCAT(SUM(amount), ' NEFT') as rarities
FROM staked_tokens 
WHERE wallet_address = :'wallet_address';

\echo ''

-- =============================================================================
-- TEST 2: Check Rewards History
-- =============================================================================
\echo '📜 TEST 2: Your Rewards History'
\echo '─────────────────────────────────────────────────────────────────────────'

SELECT 
    reward_date,
    nft_earned_today,
    token_earned_today,
    (nft_earned_today + token_earned_today) as total_today,
    is_claimed,
    CASE 
        WHEN is_claimed THEN '✅ Claimed'
        ELSE '⏳ Pending'
    END as status,
    last_updated
FROM staking_rewards 
WHERE wallet_address = :'wallet_address'
ORDER BY reward_date DESC
LIMIT 10;

\echo ''

-- =============================================================================
-- TEST 3: Calculate Expected vs Actual Rewards
-- =============================================================================
\echo '🧮 TEST 3: Expected vs Actual Rewards'
\echo '─────────────────────────────────────────────────────────────────────────'

WITH stake_info AS (
    -- Get staking start dates
    SELECT 
        MIN(staked_at) as first_nft_staked,
        COUNT(*) as nft_count,
        SUM(daily_reward) as nft_daily_total
    FROM staked_nfts 
    WHERE wallet_address = :'wallet_address'
),
token_info AS (
    SELECT 
        MIN(staked_at) as first_token_staked,
        SUM(amount) as token_amount,
        SUM(daily_reward) as token_daily_total
    FROM staked_tokens 
    WHERE wallet_address = :'wallet_address'
),
actual_rewards AS (
    SELECT 
        COUNT(DISTINCT reward_date) as days_rewarded,
        SUM(nft_earned_today) as actual_nft_rewards,
        SUM(token_earned_today) as actual_token_rewards
    FROM staking_rewards 
    WHERE wallet_address = :'wallet_address'
)
SELECT 
    si.nft_count as nfts_staked,
    si.first_nft_staked,
    EXTRACT(DAY FROM NOW() - si.first_nft_staked) as days_since_nft_stake,
    si.nft_daily_total as nft_daily_reward,
    (EXTRACT(DAY FROM NOW() - si.first_nft_staked) * si.nft_daily_total) as expected_nft_total,
    COALESCE(ar.actual_nft_rewards, 0) as actual_nft_total,
    ti.token_amount as tokens_staked,
    ti.first_token_staked,
    EXTRACT(DAY FROM NOW() - ti.first_token_staked) as days_since_token_stake,
    ti.token_daily_total as token_daily_reward,
    (EXTRACT(DAY FROM NOW() - ti.first_token_staked) * ti.token_daily_total) as expected_token_total,
    COALESCE(ar.actual_token_rewards, 0) as actual_token_total,
    COALESCE(ar.days_rewarded, 0) as days_actually_rewarded,
    CASE 
        WHEN ar.days_rewarded IS NULL OR ar.days_rewarded = 0 THEN 
            '❌ NO REWARDS GENERATED YET!'
        WHEN ar.days_rewarded < GREATEST(
            EXTRACT(DAY FROM NOW() - si.first_nft_staked),
            EXTRACT(DAY FROM NOW() - ti.first_token_staked)
        ) THEN 
            '⚠️  MISSING REWARD DAYS'
        ELSE 
            '✅ All days rewarded'
    END as status
FROM stake_info si
CROSS JOIN token_info ti
LEFT JOIN actual_rewards ar ON true;

\echo ''

-- =============================================================================
-- TEST 4: Check Pending (Unclaimed) Rewards
-- =============================================================================
\echo '💰 TEST 4: Your Pending Rewards'
\echo '─────────────────────────────────────────────────────────────────────────'

SELECT 
    SUM(nft_earned_today) as pending_nft_rewards,
    SUM(token_earned_today) as pending_token_rewards,
    SUM(nft_earned_today + token_earned_today) as total_pending,
    COUNT(*) as unclaimed_days,
    CASE 
        WHEN SUM(nft_earned_today + token_earned_today) > 0.01 THEN 
            '✅ READY TO CLAIM'
        ELSE 
            '⏳ No rewards to claim yet'
    END as claim_status
FROM staking_rewards 
WHERE wallet_address = :'wallet_address' 
  AND is_claimed = false;

\echo ''

-- =============================================================================
-- TEST 5: Test Summary Function
-- =============================================================================
\echo '📊 TEST 5: Summary Function Output'
\echo '─────────────────────────────────────────────────────────────────────────'

SELECT get_user_staking_summary(:'wallet_address') as summary;

\echo ''

-- =============================================================================
-- DIAGNOSIS & RECOMMENDATIONS
-- =============================================================================
\echo '🔍 DIAGNOSIS & RECOMMENDATIONS'
\echo '─────────────────────────────────────────────────────────────────────────'

DO $$
DECLARE
    nft_count INTEGER;
    token_count INTEGER;
    reward_count INTEGER;
    pending_rewards DECIMAL;
    days_staked INTEGER;
    cron_exists BOOLEAN;
BEGIN
    -- Get counts
    SELECT COUNT(*) INTO nft_count FROM staked_nfts WHERE wallet_address = :'wallet_address';
    SELECT COUNT(*) INTO token_count FROM staked_tokens WHERE wallet_address = :'wallet_address';
    SELECT COUNT(*) INTO reward_count FROM staking_rewards WHERE wallet_address = :'wallet_address';
    SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0) INTO pending_rewards 
    FROM staking_rewards WHERE wallet_address = :'wallet_address' AND is_claimed = false;
    
    -- Check cron job
    SELECT EXISTS(SELECT 1 FROM cron.job WHERE jobname LIKE '%staking%' AND active = true) 
    INTO cron_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'DIAGNOSIS REPORT';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Your Staking Status:';
    RAISE NOTICE '  • NFTs Staked: %', nft_count;
    RAISE NOTICE '  • Tokens Staked: %', token_count;
    RAISE NOTICE '  • Reward Records: %', reward_count;
    RAISE NOTICE '  • Pending Rewards: % NEFT', pending_rewards;
    RAISE NOTICE '  • Cron Job: %', CASE WHEN cron_exists THEN '✅ Active' ELSE '❌ Not configured' END;
    RAISE NOTICE '';
    
    -- Diagnosis
    IF nft_count = 0 AND token_count = 0 THEN
        RAISE NOTICE '❌ ISSUE: No staked assets found';
        RAISE NOTICE '   → Verify you are using the correct wallet address';
        RAISE NOTICE '   → Check if staking transaction was successful';
    ELSIF reward_count = 0 THEN
        RAISE NOTICE '❌ ISSUE: No rewards have been generated';
        RAISE NOTICE '   → Run: SELECT generate_daily_staking_rewards();';
        RAISE NOTICE '   → Setup cron job for automatic generation';
    ELSIF pending_rewards = 0 THEN
        RAISE NOTICE '⚠️  ISSUE: Rewards generated but all claimed or no new rewards';
        RAISE NOTICE '   → Check if you already claimed rewards';
        RAISE NOTICE '   → Wait for next reward cycle (every 6 hours with cron)';
    ELSE
        RAISE NOTICE '✅ SYSTEM WORKING: You have % NEFT pending rewards', pending_rewards;
        RAISE NOTICE '   → Refresh your staking page to see updated values';
        RAISE NOTICE '   → Claim button should be enabled';
    END IF;
    
    RAISE NOTICE '';
    
    -- Recommendations
    IF NOT cron_exists THEN
        RAISE NOTICE '🔧 ACTION NEEDED: Setup cron job';
        RAISE NOTICE '   Run this command:';
        RAISE NOTICE '   SELECT cron.schedule(';
        RAISE NOTICE '       ''generate-staking-rewards-6h'',';
        RAISE NOTICE '       ''0 */6 * * *'',';
        RAISE NOTICE '       $$SELECT generate_daily_staking_rewards();$$';
        RAISE NOTICE '   );';
        RAISE NOTICE '';
    END IF;
    
    IF reward_count = 0 AND (nft_count > 0 OR token_count > 0) THEN
        RAISE NOTICE '⚡ IMMEDIATE FIX: Generate rewards now';
        RAISE NOTICE '   Run: SELECT generate_daily_staking_rewards();';
        RAISE NOTICE '';
    END IF;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════';
END $$;

\echo ''
\echo '✅ Testing complete! Review the output above for your staking status.'
\echo ''
\echo '📝 Quick Commands:'
\echo '   • Generate rewards: SELECT generate_daily_staking_rewards();'
\echo '   • Check summary: SELECT get_user_staking_summary(''YOUR_WALLET'');'
\echo '   • Setup cron: See QUICK_FIX_PENDING_REWARDS.sql'
\echo ''
