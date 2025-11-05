-- ============================================================================
-- TEST CURRENT LEADERBOARD DATA
-- Verify your NFT counting system and data availability
-- ============================================================================

-- 1. Check if user_nft_counts table exists and has data
SELECT 'Testing user_nft_counts table:' as test_step;
SELECT 
    COUNT(*) as total_users,
    SUM(total_nfts) as total_nfts_across_users,
    AVG(total_nfts) as avg_nfts_per_user,
    MAX(total_nfts) as highest_nft_count
FROM user_nft_counts
WHERE total_nfts > 0;

-- 2. Show top 5 NFT holders (current system)
SELECT 'Current top 5 NFT holders:' as test_step;
SELECT 
    wallet_address,
    total_nfts,
    offchain_nfts,
    onchain_nfts,
    staked_nfts,
    last_updated
FROM user_nft_counts
WHERE total_nfts > 0
ORDER BY total_nfts DESC
LIMIT 5;

-- 3. Test existing optimized function (if it exists)
SELECT 'Testing existing get_nft_leaderboard_optimized function:' as test_step;
DO $$
BEGIN
    -- Try to call the existing function
    BEGIN
        PERFORM get_nft_leaderboard_optimized(5, '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071');
        RAISE NOTICE 'get_nft_leaderboard_optimized function exists and works';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'get_nft_leaderboard_optimized function issue: %', SQLERRM;
    END;
END $$;

-- 4. Check if specific user has NFT count data
SELECT 'Testing specific user NFT data:' as test_step;
SELECT 
    wallet_address,
    total_nfts,
    offchain_nfts,
    onchain_nfts,
    staked_nfts,
    (SELECT COUNT(*) + 1 FROM user_nft_counts unc2 
     WHERE unc2.total_nfts > unc.total_nfts) as calculated_rank
FROM user_nft_counts unc
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- 5. Check NEFT leaderboard data source
SELECT 'Testing NEFT leaderboard data source:' as test_step;
SELECT 
    COUNT(*) as total_users_with_neft,
    SUM(total_neft_claimed) as total_neft_distributed,
    AVG(total_neft_claimed) as avg_neft_per_user,
    MAX(total_neft_claimed) as highest_neft_balance
FROM user_balances
WHERE total_neft_claimed > 0;

-- 6. Show data structure compatibility
SELECT 'Checking table structure compatibility:' as test_step;
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_nft_counts'
ORDER BY ordinal_position;

-- Summary
DO $$
BEGIN
    RAISE NOTICE ' ';
    RAISE NOTICE 'CURRENT SYSTEM ANALYSIS COMPLETE';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE ' ';
    RAISE NOTICE 'What the optimized system needs:';
    RAISE NOTICE '   1. user_nft_counts table with NFT count data';
    RAISE NOTICE '   2. user_balances table with NEFT balance data';
    RAISE NOTICE '   3. Optional user_profiles table for usernames';
    RAISE NOTICE ' ';
    RAISE NOTICE 'Benefits of optimized system:';
    RAISE NOTICE '   Single RPC call vs 3-5 calls (80 percent reduction)';
    RAISE NOTICE '   Server-side filtering vs client-side processing';
    RAISE NOTICE '   Efficient rank calculation vs 1000-user downloads';
    RAISE NOTICE '   Built-in caching vs repeated calls';
    RAISE NOTICE ' ';
END $$;
