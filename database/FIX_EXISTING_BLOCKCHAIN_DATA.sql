-- ============================================================================
-- FIX EXISTING BLOCKCHAIN DATA - Update default 'polygon' to actual network names
-- ============================================================================
-- Problem: Existing staked NFTs have blockchain='polygon' but frontend uses 'polygon-amoy'
-- Solution: Update existing data to use correct network names
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '🔄 Updating existing staked NFTs blockchain values...';
    
    -- Update staked_nfts: 'polygon' -> 'polygon-amoy'
    UPDATE staked_nfts 
    SET blockchain = 'polygon-amoy' 
    WHERE blockchain = 'polygon' OR blockchain IS NULL;
    
    RAISE NOTICE '✅ Updated staked_nfts to use polygon-amoy';
    
    -- Update staking_rewards: 'polygon' -> 'polygon-amoy'
    UPDATE staking_rewards 
    SET blockchain = 'polygon-amoy' 
    WHERE blockchain = 'polygon' OR blockchain IS NULL;
    
    RAISE NOTICE '✅ Updated staking_rewards to use polygon-amoy';
    
    -- Show updated counts
    RAISE NOTICE '';
    RAISE NOTICE '📊 Updated Records:';
    RAISE NOTICE '   Staked NFTs with polygon-amoy: %', (SELECT COUNT(*) FROM staked_nfts WHERE blockchain = 'polygon-amoy');
    RAISE NOTICE '   Staking rewards with polygon-amoy: %', (SELECT COUNT(*) FROM staking_rewards WHERE blockchain = 'polygon-amoy');
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration complete! Pending rewards should now show correctly.';
END $$;

-- Verify the changes
SELECT 
    'Staked NFTs by blockchain' as table_name,
    blockchain,
    COUNT(*) as count
FROM staked_nfts 
GROUP BY blockchain
UNION ALL
SELECT 
    'Staking rewards by blockchain',
    blockchain,
    COUNT(*)
FROM staking_rewards
GROUP BY blockchain;
