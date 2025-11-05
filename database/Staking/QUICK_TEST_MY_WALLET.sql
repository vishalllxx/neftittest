-- ============================================================================
-- QUICK TEST: Check YOUR specific wallet rewards
-- ============================================================================
-- 🔧 REPLACE WITH YOUR WALLET ADDRESS:
\set MY_WALLET 'YOUR_WALLET_ADDRESS_HERE'

-- Or set it directly in the queries below

-- ============================================================================
-- STEP 1: Check YOUR staked assets
-- ============================================================================
SELECT 
    '🎨 Your Staked NFTs' as info,
    nft_id,
    rarity,
    daily_reward,
    staked_at,
    EXTRACT(DAYS FROM (NOW() - staked_at))::INTEGER as days_staked,
    (daily_reward * EXTRACT(DAYS FROM (NOW() - staked_at)))::NUMERIC(10,4) as expected_total_rewards
FROM staked_nfts 
WHERE wallet_address = :'MY_WALLET'  -- Replace with your actual wallet if \set doesn't work
ORDER BY staked_at;

SELECT 
    '🪙 Your Staked Tokens' as info,
    amount,
    daily_reward,
    apr_rate,
    staked_at,
    EXTRACT(DAYS FROM (NOW() - staked_at))::INTEGER as days_staked,
    (daily_reward * EXTRACT(DAYS FROM (NOW() - staked_at)))::NUMERIC(10,4) as expected_total_rewards
FROM staked_tokens 
WHERE wallet_address = :'MY_WALLET'
ORDER BY staked_at;

-- ============================================================================
-- STEP 2: Check existing rewards in database
-- ============================================================================
SELECT 
    '💰 Rewards Generated in Database' as info,
    reward_date,
    nft_rewards,
    token_rewards,
    (COALESCE(nft_rewards, 0) + COALESCE(token_rewards, 0)) as total_daily,
    is_claimed,
    reward_amount,
    last_updated
FROM staking_rewards 
WHERE wallet_address = :'MY_WALLET'
ORDER BY reward_date DESC;

-- Count total records
SELECT 
    '📊 Rewards Summary' as info,
    COUNT(*) as total_reward_days,
    SUM(COALESCE(nft_rewards, 0)) as total_nft_rewards,
    SUM(COALESCE(token_rewards, 0)) as total_token_rewards,
    SUM(COALESCE(nft_rewards, 0) + COALESCE(token_rewards, 0)) as grand_total,
    COUNT(*) FILTER (WHERE is_claimed = TRUE) as days_claimed,
    COUNT(*) FILTER (WHERE is_claimed = FALSE) as days_unclaimed
FROM staking_rewards 
WHERE wallet_address = :'MY_WALLET';

-- ============================================================================
-- STEP 3: Get staking summary (what UI should show)
-- ============================================================================
SELECT 
    '📊 Staking Summary (UI Data)' as info,
    get_user_staking_summary(:'MY_WALLET') as summary;

-- ============================================================================
-- STEP 4: GENERATE REWARDS NOW (if missing)
-- ============================================================================
-- This will generate rewards for ALL wallets
SELECT 
    '🚀 Generating Rewards...' as status,
    generate_daily_staking_rewards() as wallets_processed;

-- ============================================================================
-- STEP 5: Check again after generation
-- ============================================================================
SELECT 
    '✅ Updated Summary After Generation' as info,
    get_user_staking_summary(:'MY_WALLET') as summary;

-- View new rewards
SELECT 
    '💰 Latest Rewards' as info,
    reward_date,
    nft_rewards,
    token_rewards,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = :'MY_WALLET'
ORDER BY reward_date DESC
LIMIT 10;

-- ============================================================================
-- EXPECTED vs ACTUAL
-- ============================================================================
WITH expected AS (
    SELECT 
        SUM(daily_reward) as daily_nft,
        MAX(EXTRACT(DAYS FROM (NOW() - staked_at))::INTEGER) as days,
        SUM(daily_reward) * MAX(EXTRACT(DAYS FROM (NOW() - staked_at))::INTEGER) as total_expected
    FROM staked_nfts 
    WHERE wallet_address = :'MY_WALLET'
),
actual AS (
    SELECT 
        SUM(COALESCE(nft_rewards, 0)) as total_actual
    FROM staking_rewards 
    WHERE wallet_address = :'MY_WALLET'
)
SELECT 
    '🔍 NFT Rewards Analysis' as analysis,
    e.daily_nft as daily_nft_reward,
    e.days as days_staked,
    e.total_expected as expected_total,
    COALESCE(a.total_actual, 0) as actual_generated,
    e.total_expected - COALESCE(a.total_actual, 0) as missing_rewards,
    CASE 
        WHEN e.total_expected - COALESCE(a.total_actual, 0) > 0 THEN '❌ MISSING REWARDS!'
        ELSE '✅ All rewards generated'
    END as status
FROM expected e
CROSS JOIN actual a;

-- ============================================================================
-- FINAL DIAGNOSTIC
-- ============================================================================
DO $$
DECLARE
    nft_count INTEGER;
    token_count INTEGER;
    reward_count INTEGER;
    days_staked INTEGER;
    expected_days INTEGER;
BEGIN
    -- Get counts
    SELECT COUNT(*) INTO nft_count FROM staked_nfts WHERE wallet_address = :'MY_WALLET';
    SELECT COUNT(*) INTO token_count FROM staked_tokens WHERE wallet_address = :'MY_WALLET';
    SELECT COUNT(*) INTO reward_count FROM staking_rewards WHERE wallet_address = :'MY_WALLET';
    SELECT MAX(EXTRACT(DAYS FROM (NOW() - staked_at))::INTEGER) INTO days_staked 
    FROM staked_nfts WHERE wallet_address = :'MY_WALLET';
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '📋 DIAGNOSTIC REPORT FOR YOUR WALLET';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📌 Wallet: %', :'MY_WALLET';
    RAISE NOTICE '';
    RAISE NOTICE '🎨 Staked NFTs: %', COALESCE(nft_count, 0);
    RAISE NOTICE '🪙 Staked Token Positions: %', COALESCE(token_count, 0);
    RAISE NOTICE '⏰ Days Staked: %', COALESCE(days_staked, 0);
    RAISE NOTICE '💰 Reward Records Generated: %', COALESCE(reward_count, 0);
    RAISE NOTICE '';
    
    IF COALESCE(reward_count, 0) = 0 THEN
        RAISE NOTICE '❌ ISSUE FOUND: No rewards generated!';
        RAISE NOTICE '   → Cron job is not running';
        RAISE NOTICE '   → Run: SELECT generate_daily_staking_rewards();';
    ELSIF COALESCE(days_staked, 0) > COALESCE(reward_count, 0) THEN
        RAISE NOTICE '⚠️  ISSUE FOUND: Missing reward records!';
        RAISE NOTICE '   → Expected ~% reward days, but only % exist', days_staked, reward_count;
        RAISE NOTICE '   → Run: SELECT generate_daily_staking_rewards();';
    ELSE
        RAISE NOTICE '✅ Rewards are being generated correctly';
        RAISE NOTICE '   → If UI shows 0, check EnhancedStakingService';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 NEXT STEPS:';
    RAISE NOTICE '   1. Run above queries to see detailed data';
    RAISE NOTICE '   2. Check browser console for service errors';
    RAISE NOTICE '   3. Verify wallet address matches exactly';
    RAISE NOTICE '';
END $$;
