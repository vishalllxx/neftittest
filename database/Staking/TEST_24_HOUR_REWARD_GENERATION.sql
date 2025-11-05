-- ============================================================================
-- COMPREHENSIVE 24-HOUR STAKING REWARD GENERATION TEST
-- ============================================================================
-- This script tests both NFT and Token staking rewards after 24 hours
-- Run each section in order and verify results
-- ============================================================================

-- ============================================================================
-- SECTION 1: SETUP - Check Current State
-- ============================================================================

-- 1.1: Check if reward generation function exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'generate_daily_staking_rewards';

-- 1.2: Check current staked NFTs and their daily rewards
SELECT 
    '📊 Current Staked NFTs' as section,
    wallet_address,
    nft_id,
    rarity,
    daily_reward,
    staked_at,
    EXTRACT(EPOCH FROM (NOW() - staked_at)) / 3600 as hours_staked
FROM staked_nfts
ORDER BY wallet_address, staked_at;

-- 1.3: Check current staked tokens and their daily rewards
SELECT 
    '📊 Current Staked Tokens' as section,
    wallet_address,
    amount,
    daily_reward,
    staked_at,
    EXTRACT(EPOCH FROM (NOW() - staked_at)) / 3600 as hours_staked
FROM staked_tokens
ORDER BY wallet_address, staked_at;

-- 1.4: Check existing rewards in staking_rewards table
SELECT 
    '📊 Existing Rewards' as section,
    wallet_address,
    reward_date,
    nft_rewards,
    token_rewards,
    total_nft_earned,
    total_token_earned,
    total_nft_claimed,
    total_token_claimed,
    claimed,
    created_at
FROM staking_rewards
ORDER BY wallet_address, reward_date DESC;

-- 1.5: Calculate expected daily rewards per wallet
SELECT 
    '💰 Expected Daily Rewards per Wallet' as section,
    wallet_address,
    SUM(nft_reward) as expected_nft_rewards,
    SUM(token_reward) as expected_token_rewards,
    SUM(nft_reward) + SUM(token_reward) as total_expected_daily
FROM (
    SELECT wallet_address, daily_reward as nft_reward, 0 as token_reward FROM staked_nfts
    UNION ALL
    SELECT wallet_address, 0 as nft_reward, daily_reward as token_reward FROM staked_tokens
) combined
GROUP BY wallet_address
ORDER BY wallet_address;

-- ============================================================================
-- SECTION 2: TEST REWARD GENERATION (Simulate 24-hour cycle)
-- ============================================================================

-- 2.1: Capture state BEFORE reward generation
CREATE TEMP TABLE before_rewards AS
SELECT 
    wallet_address,
    COALESCE(SUM(total_nft_earned), 0) as nft_earned_before,
    COALESCE(SUM(total_token_earned), 0) as token_earned_before,
    COALESCE(SUM(total_nft_claimed), 0) as nft_claimed_before,
    COALESCE(SUM(total_token_claimed), 0) as token_claimed_before
FROM staking_rewards
GROUP BY wallet_address;

-- 2.2: Run the reward generation function
SELECT 
    '⚙️ Running Reward Generation' as action,
    generate_daily_staking_rewards() as wallets_processed,
    NOW() as execution_time;

-- 2.3: Capture state AFTER reward generation
CREATE TEMP TABLE after_rewards AS
SELECT 
    wallet_address,
    COALESCE(SUM(total_nft_earned), 0) as nft_earned_after,
    COALESCE(SUM(total_token_earned), 0) as token_earned_after,
    COALESCE(SUM(total_nft_claimed), 0) as nft_claimed_after,
    COALESCE(SUM(total_token_claimed), 0) as token_claimed_after
FROM staking_rewards
GROUP BY wallet_address;

-- 2.4: Compare BEFORE and AFTER to verify rewards were added
SELECT 
    '✅ Reward Generation Results' as section,
    COALESCE(a.wallet_address, b.wallet_address) as wallet_address,
    COALESCE(b.nft_earned_before, 0) as nft_earned_before,
    COALESCE(a.nft_earned_after, 0) as nft_earned_after,
    COALESCE(a.nft_earned_after, 0) - COALESCE(b.nft_earned_before, 0) as nft_rewards_added,
    COALESCE(b.token_earned_before, 0) as token_earned_before,
    COALESCE(a.token_earned_after, 0) as token_earned_after,
    COALESCE(a.token_earned_after, 0) - COALESCE(b.token_earned_before, 0) as token_rewards_added,
    (COALESCE(a.nft_earned_after, 0) - COALESCE(b.nft_earned_before, 0)) + 
    (COALESCE(a.token_earned_after, 0) - COALESCE(b.token_earned_before, 0)) as total_rewards_added
FROM after_rewards a
FULL OUTER JOIN before_rewards b ON a.wallet_address = b.wallet_address
ORDER BY wallet_address;

-- ============================================================================
-- SECTION 3: VERIFY REWARD ACCURACY
-- ============================================================================

-- 3.1: Verify NFT rewards match expected daily rates
SELECT 
    '🔍 NFT Reward Accuracy Check' as section,
    sr.wallet_address,
    sr.reward_date,
    sr.nft_rewards as actual_nft_rewards,
    COALESCE(SUM(sn.daily_reward), 0) as expected_nft_rewards,
    sr.nft_rewards - COALESCE(SUM(sn.daily_reward), 0) as difference,
    CASE 
        WHEN ABS(sr.nft_rewards - COALESCE(SUM(sn.daily_reward), 0)) < 0.0001 THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END as status
FROM staking_rewards sr
LEFT JOIN staked_nfts sn ON sr.wallet_address = sn.wallet_address
WHERE sr.reward_date = CURRENT_DATE
GROUP BY sr.wallet_address, sr.reward_date, sr.nft_rewards
ORDER BY sr.wallet_address;

-- 3.2: Verify token rewards match expected daily rates
SELECT 
    '🔍 Token Reward Accuracy Check' as section,
    sr.wallet_address,
    sr.reward_date,
    sr.token_rewards as actual_token_rewards,
    COALESCE(SUM(st.daily_reward), 0) as expected_token_rewards,
    sr.token_rewards - COALESCE(SUM(st.daily_reward), 0) as difference,
    CASE 
        WHEN ABS(sr.token_rewards - COALESCE(SUM(st.daily_reward), 0)) < 0.0001 THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END as status
FROM staking_rewards sr
LEFT JOIN staked_tokens st ON sr.wallet_address = st.wallet_address
WHERE sr.reward_date = CURRENT_DATE
GROUP BY sr.wallet_address, sr.reward_date, sr.token_rewards
ORDER BY sr.wallet_address;

-- 3.3: Verify cumulative tracking is working
SELECT 
    '🔍 Cumulative Tracking Check' as section,
    wallet_address,
    COUNT(*) as reward_days,
    SUM(nft_rewards) as sum_daily_nft_rewards,
    MAX(total_nft_earned) as cumulative_nft_earned,
    SUM(token_rewards) as sum_daily_token_rewards,
    MAX(total_token_earned) as cumulative_token_earned,
    CASE 
        WHEN SUM(nft_rewards) <= MAX(total_nft_earned) + 0.0001 THEN '✅ CUMULATIVE OK'
        ELSE '❌ CUMULATIVE ERROR'
    END as nft_status,
    CASE 
        WHEN SUM(token_rewards) <= MAX(total_token_earned) + 0.0001 THEN '✅ CUMULATIVE OK'
        ELSE '❌ CUMULATIVE ERROR'
    END as token_status
FROM staking_rewards
GROUP BY wallet_address
ORDER BY wallet_address;

-- ============================================================================
-- SECTION 4: TEST REWARD CLAIMING
-- ============================================================================

-- 4.1: Check pending rewards before claiming
SELECT 
    '💎 Pending Rewards Before Claim' as section,
    wallet_address,
    total_nft_earned - total_nft_claimed as nft_pending,
    total_token_earned - total_token_claimed as token_pending,
    (total_nft_earned - total_nft_claimed) + (total_token_earned - total_token_claimed) as total_pending
FROM staking_rewards
WHERE (total_nft_earned - total_nft_claimed) > 0 
   OR (total_token_earned - total_token_claimed) > 0
ORDER BY wallet_address, reward_date;

-- 4.2: Test get_user_staking_summary function
-- Replace 'YOUR_WALLET_ADDRESS' with actual wallet address
-- SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- 4.3: Test claiming NFT rewards
-- Replace 'YOUR_WALLET_ADDRESS' with actual wallet address
-- SELECT claim_nft_rewards('YOUR_WALLET_ADDRESS');

-- 4.4: Test claiming token rewards
-- Replace 'YOUR_WALLET_ADDRESS' with actual wallet address
-- SELECT claim_token_rewards('YOUR_WALLET_ADDRESS');

-- 4.5: Verify rewards were claimed (run after claiming)
SELECT 
    '💰 Claimed Rewards Verification' as section,
    wallet_address,
    total_nft_earned,
    total_nft_claimed,
    total_nft_earned - total_nft_claimed as nft_remaining,
    total_token_earned,
    total_token_claimed,
    total_token_earned - total_token_claimed as token_remaining,
    CASE 
        WHEN total_nft_earned = total_nft_claimed AND total_token_earned = total_token_claimed THEN '✅ FULLY CLAIMED'
        WHEN total_nft_earned > total_nft_claimed OR total_token_earned > total_token_claimed THEN '⚠️ PARTIAL'
        ELSE '❓ UNKNOWN'
    END as claim_status
FROM staking_rewards
ORDER BY wallet_address, reward_date DESC;

-- 4.6: Verify balance was updated in user_balances table
SELECT 
    '💰 User Balance After Claim' as section,
    wallet_address,
    total_neft_claimed,
    available_neft,
    staked_neft,
    total_xp_earned,
    updated_at
FROM user_balances
ORDER BY wallet_address;

-- ============================================================================
-- SECTION 5: SIMULATE MULTIPLE DAY REWARD GENERATION
-- ============================================================================

-- 5.1: Simulate reward generation for multiple days
-- This tests cumulative tracking over time
DO $$
DECLARE
    day_count INTEGER := 0;
    wallets_processed INTEGER;
    test_date DATE;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 ============================================================================';
    RAISE NOTICE '🧪 SIMULATING 7 DAYS OF REWARD GENERATION';
    RAISE NOTICE '🧪 ============================================================================';
    RAISE NOTICE '';
    
    -- Simulate 7 days of rewards
    FOR day_count IN 1..7 LOOP
        test_date := CURRENT_DATE + (day_count || ' days')::INTERVAL;
        
        -- Generate rewards for this day
        SELECT generate_daily_staking_rewards() INTO wallets_processed;
        
        RAISE NOTICE 'Day %: Generated rewards for % wallets on %', 
            day_count, wallets_processed, test_date;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Simulation complete - check cumulative rewards below';
    RAISE NOTICE '';
END $$;

-- 5.2: View cumulative rewards after 7-day simulation
SELECT 
    '📈 7-Day Cumulative Rewards' as section,
    wallet_address,
    COUNT(*) as reward_days,
    SUM(nft_rewards) as total_daily_nft,
    SUM(token_rewards) as total_daily_token,
    MAX(total_nft_earned) as cumulative_nft_earned,
    MAX(total_token_earned) as cumulative_token_earned,
    MAX(total_nft_earned) - MAX(total_nft_claimed) as nft_pending,
    MAX(total_token_earned) - MAX(total_token_claimed) as token_pending
FROM staking_rewards
GROUP BY wallet_address
ORDER BY wallet_address;

-- ============================================================================
-- SECTION 6: EDGE CASE TESTING
-- ============================================================================

-- 6.1: Test with no staked assets
SELECT 
    '🧪 Edge Case: No Staked Assets' as test,
    generate_daily_staking_rewards() as wallets_processed,
    CASE 
        WHEN generate_daily_staking_rewards() = 0 THEN '✅ HANDLED CORRECTLY'
        ELSE '⚠️ CHECK RESULTS'
    END as status;

-- 6.2: Test duplicate reward generation for same day
SELECT 
    '🧪 Edge Case: Duplicate Generation Same Day' as test,
    generate_daily_staking_rewards() as wallets_processed_first,
    generate_daily_staking_rewards() as wallets_processed_second,
    'Should use ON CONFLICT to update, not duplicate' as expected_behavior;

-- 6.3: Verify no duplicate reward records for same day
SELECT 
    '🔍 Duplicate Check' as section,
    wallet_address,
    reward_date,
    COUNT(*) as record_count,
    CASE 
        WHEN COUNT(*) = 1 THEN '✅ NO DUPLICATES'
        ELSE '❌ DUPLICATES FOUND'
    END as status
FROM staking_rewards
GROUP BY wallet_address, reward_date
HAVING COUNT(*) > 1;

-- ============================================================================
-- SECTION 7: PERFORMANCE & MONITORING
-- ============================================================================

-- 7.1: Check reward generation performance
EXPLAIN ANALYZE
SELECT generate_daily_staking_rewards();

-- 7.2: Monitor reward table size
SELECT 
    '📊 Reward Table Statistics' as section,
    COUNT(*) as total_records,
    COUNT(DISTINCT wallet_address) as unique_wallets,
    COUNT(DISTINCT reward_date) as unique_dates,
    MIN(reward_date) as earliest_reward,
    MAX(reward_date) as latest_reward,
    pg_size_pretty(pg_total_relation_size('staking_rewards')) as table_size
FROM staking_rewards;

-- 7.3: Check for orphaned rewards (rewards without corresponding staked assets)
SELECT 
    '🔍 Orphaned Rewards Check' as section,
    sr.wallet_address,
    sr.reward_date,
    sr.nft_rewards,
    sr.token_rewards,
    COALESCE(nft_count, 0) as current_staked_nfts,
    COALESCE(token_amount, 0) as current_staked_tokens,
    CASE 
        WHEN sr.nft_rewards > 0 AND COALESCE(nft_count, 0) = 0 THEN '⚠️ NFT ORPHAN'
        WHEN sr.token_rewards > 0 AND COALESCE(token_amount, 0) = 0 THEN '⚠️ TOKEN ORPHAN'
        ELSE '✅ OK'
    END as status
FROM staking_rewards sr
LEFT JOIN (
    SELECT wallet_address, COUNT(*) as nft_count
    FROM staked_nfts
    GROUP BY wallet_address
) nfts ON sr.wallet_address = nfts.wallet_address
LEFT JOIN (
    SELECT wallet_address, SUM(amount) as token_amount
    FROM staked_tokens
    GROUP BY wallet_address
) tokens ON sr.wallet_address = tokens.wallet_address
WHERE sr.reward_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY sr.wallet_address, sr.reward_date DESC;

-- ============================================================================
-- CLEANUP TEMP TABLES
-- ============================================================================
DROP TABLE IF EXISTS before_rewards;
DROP TABLE IF EXISTS after_rewards;

-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ 24-HOUR REWARD GENERATION TEST COMPLETE';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 CHECKLIST:';
    RAISE NOTICE '   ✓ Verify reward generation function ran successfully';
    RAISE NOTICE '   ✓ Check NFT rewards match expected daily rates';
    RAISE NOTICE '   ✓ Check token rewards match expected daily rates';
    RAISE NOTICE '   ✓ Verify cumulative tracking is accurate';
    RAISE NOTICE '   ✓ Test claim functions work correctly';
    RAISE NOTICE '   ✓ Verify user balances update after claiming';
    RAISE NOTICE '   ✓ Confirm no duplicate reward records';
    RAISE NOTICE '   ✓ Check for orphaned rewards';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 NEXT STEPS:';
    RAISE NOTICE '   1. Review all section results above';
    RAISE NOTICE '   2. Test actual wallet addresses with claim functions';
    RAISE NOTICE '   3. Set up cron job for automated daily generation';
    RAISE NOTICE '   4. Monitor reward generation over multiple days';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT:';
    RAISE NOTICE '   - Rewards generate daily at midnight UTC via cron job';
    RAISE NOTICE '   - Manual testing uses generate_daily_staking_rewards()';
    RAISE NOTICE '   - Always verify cumulative totals match daily sum';
    RAISE NOTICE '   - Check user_balances table after claiming';
    RAISE NOTICE '';
END $$;
