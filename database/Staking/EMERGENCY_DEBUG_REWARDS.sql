-- =============================================================================
-- EMERGENCY DEBUG: Find Why Rewards Not Showing
-- =============================================================================
-- Wallet: 0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071
-- =============================================================================

-- =============================================================================
-- STEP 1: Verify staking_rewards table exists and check structure
-- =============================================================================

SELECT 
    'Table Structure Check' as info,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'staking_rewards'
ORDER BY ordinal_position;

-- =============================================================================
-- STEP 2: Check if ANY rewards exist in the entire table
-- =============================================================================

SELECT 
    'Total Rewards in Database' as info,
    COUNT(*) as total_records,
    COUNT(DISTINCT wallet_address) as unique_wallets,
    MAX(reward_date) as latest_reward_date
FROM staking_rewards;

-- =============================================================================
-- STEP 3: Check YOUR specific wallet rewards (try both cases)
-- =============================================================================

-- Try lowercase
SELECT 
    'Your Rewards (lowercase)' as info,
    COUNT(*) as record_count,
    COALESCE(SUM(nft_earned_today), 0) as nft_pending,
    COALESCE(SUM(token_earned_today), 0) as token_pending
FROM staking_rewards 
WHERE LOWER(wallet_address) = LOWER('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071')
  AND is_claimed = false;

-- Check what wallet addresses exist (show first 5)
SELECT 
    'Wallet Addresses in Table' as info,
    wallet_address,
    COUNT(*) as record_count
FROM staking_rewards
GROUP BY wallet_address
LIMIT 5;

-- =============================================================================
-- STEP 4: Test the summary function directly
-- =============================================================================

SELECT 
    'Summary Function Test' as info,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as result;

-- =============================================================================
-- STEP 5: Check if generate_daily_staking_rewards function exists
-- =============================================================================

SELECT 
    'Function Exists' as info,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'generate_daily_staking_rewards';

-- =============================================================================
-- STEP 6: FORCE generate rewards NOW
-- =============================================================================

-- First, let's see what staked_tokens has
SELECT 
    'Your Staked Tokens (for reward calc)' as info,
    COUNT(*) as position_count,
    SUM(amount) as total_amount,
    SUM(daily_reward) as total_daily_rewards,
    MIN(staked_at) as oldest_stake,
    MAX(staked_at) as newest_stake
FROM staked_tokens 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- Generate rewards
SELECT 
    'Generating Rewards NOW' as action,
    generate_daily_staking_rewards() as result;

-- =============================================================================
-- STEP 7: Check IMMEDIATELY after generation
-- =============================================================================

-- Check staking_rewards table again
SELECT 
    'After Generation - Rewards Table' as info,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as your_records
FROM staking_rewards;

-- Your specific rewards
SELECT 
    'Your Rewards After Generation' as info,
    reward_date,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed,
    blockchain,
    created_at
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY reward_date DESC;

-- Pending rewards sum
SELECT 
    'Your Pending Rewards Sum' as info,
    COALESCE(SUM(nft_earned_today), 0) as nft_pending,
    COALESCE(SUM(token_earned_today), 0) as token_pending,
    COALESCE(SUM(nft_earned_today + token_earned_today), 0) as total_pending
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND is_claimed = false;

-- =============================================================================
-- STEP 8: Test summary function again
-- =============================================================================

SELECT 
    'Summary Function After Generation' as info,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as summary;

-- =============================================================================
-- STEP 9: Check if there's a blockchain filter issue
-- =============================================================================

-- Your staked NFTs blockchain
SELECT 
    'NFT Blockchains' as info,
    blockchain,
    COUNT(*) as nft_count
FROM staked_nfts 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
GROUP BY blockchain;

-- Your staked tokens blockchain (if column exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'staked_tokens' AND column_name = 'blockchain'
    ) THEN
        RAISE NOTICE 'Checking token blockchain distribution...';
    ELSE
        RAISE NOTICE 'staked_tokens table does not have blockchain column';
    END IF;
END $$;

-- =============================================================================
-- STEP 10: Check if chain-specific summary is being used
-- =============================================================================

-- Test with Base Sepolia (from your UI screenshot)
SELECT 
    'Summary for Base Sepolia' as info,
    get_user_staking_summary_by_chain('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071', 'base-sepolia') as summary;

-- Test without blockchain filter (all chains)
SELECT 
    'Summary for All Chains' as info,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as summary;

-- =============================================================================
-- FINAL DIAGNOSIS
-- =============================================================================

DO $$
DECLARE
    v_staked_tokens INTEGER;
    v_reward_records INTEGER;
    v_pending DECIMAL;
    v_function_exists BOOLEAN;
BEGIN
    -- Check if you have staked tokens
    SELECT COUNT(*) INTO v_staked_tokens 
    FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    -- Check if rewards exist
    SELECT COUNT(*) INTO v_reward_records 
    FROM staking_rewards WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    -- Check pending
    SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0) INTO v_pending
    FROM staking_rewards 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071' 
      AND is_claimed = false;
    
    -- Check function
    SELECT EXISTS(
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'generate_daily_staking_rewards'
    ) INTO v_function_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 EMERGENCY DIAGNOSTIC RESULTS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Database Status:';
    RAISE NOTICE '   • Staked Token Positions: %', v_staked_tokens;
    RAISE NOTICE '   • Reward Records: %', v_reward_records;
    RAISE NOTICE '   • Pending Rewards: % NEFT', v_pending;
    RAISE NOTICE '   • Generation Function Exists: %', v_function_exists;
    RAISE NOTICE '';
    
    IF v_staked_tokens > 0 AND v_reward_records = 0 THEN
        RAISE NOTICE '❌ CRITICAL: You have staked tokens but NO reward records!';
        RAISE NOTICE '   → The generate_daily_staking_rewards() function failed or never ran';
        RAISE NOTICE '   → Check the "Generating Rewards NOW" output above for errors';
    ELSIF v_reward_records > 0 AND v_pending = 0 THEN
        RAISE NOTICE '⚠️  WARNING: Rewards exist but all are claimed or 0';
        RAISE NOTICE '   → Check "Your Rewards After Generation" table above';
        RAISE NOTICE '   → Look for non-zero token_earned_today values';
    ELSIF v_pending > 0 THEN
        RAISE NOTICE '✅ SUCCESS: Database has % NEFT pending rewards!', v_pending;
        RAISE NOTICE '';
        RAISE NOTICE '🔧 UI FIX REQUIRED:';
        RAISE NOTICE '   1. Your wallet: 0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
        RAISE NOTICE '   2. Database has: % NEFT', v_pending;
        RAISE NOTICE '   3. UI shows: 0.0 NEFT';
        RAISE NOTICE '';
        RAISE NOTICE '   Possible Issues:';
        RAISE NOTICE '   • Chain filter mismatch (Base Sepolia vs polygon)';
        RAISE NOTICE '   • Summary function returning wrong values';
        RAISE NOTICE '   • Frontend not refreshing after data load';
        RAISE NOTICE '';
        RAISE NOTICE '   Actions:';
        RAISE NOTICE '   • Check "Summary Function After Generation" output above';
        RAISE NOTICE '   • Check "Summary for Base Sepolia" output';
        RAISE NOTICE '   • Hard refresh browser (Ctrl + Shift + R)';
        RAISE NOTICE '   • Open browser console and check for errors';
    ELSE
        RAISE NOTICE '❌ PROBLEM: No staked tokens or rewards found';
        RAISE NOTICE '   → Verify wallet address is correct';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
END $$;
