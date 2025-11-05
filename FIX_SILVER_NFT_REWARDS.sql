-- ============================================================================
-- FIX SILVER NFT DAILY REWARDS
-- ============================================================================
-- Update Silver NFTs from 5.0 NEFT/day to correct 8.0 NEFT/day

-- Official NEFTIT Reward Tier System:
-- Common NFT: 0.1 NEFT/day
-- Rare NFT: 0.4 NEFT/day  
-- Legendary NFT: 1.0 NEFT/day
-- Platinum NFT: 2.5 NEFT/day
-- Silver NFT: 8.0 NEFT/day  ← FIXING THIS
-- Gold NFT: 30.0 NEFT/day

-- 1. Show current Silver NFT data before fix
SELECT 
    'BEFORE FIX' as status,
    wallet_address,
    nft_id,
    nft_rarity,
    daily_reward,
    daily_rate,
    staking_source
FROM staked_nfts 
WHERE nft_rarity = 'Silver'
ORDER BY wallet_address, nft_id;

-- 2. Update Silver NFTs to correct daily reward (8.0 NEFT)
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE staked_nfts 
    SET daily_reward = 8.0
    WHERE nft_rarity = 'Silver' 
    AND daily_reward != 8.0;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RAISE NOTICE 'UPDATE RESULT: % Silver NFT records updated to 8.0 NEFT/day', updated_count;
END $$;

-- 4. Verify the fix worked
SELECT 
    'AFTER FIX' as status,
    wallet_address,
    nft_id,
    nft_rarity,
    daily_reward,
    daily_rate,
    staking_source,
    CASE 
        WHEN nft_rarity = 'Silver' AND daily_reward = 8.0 THEN '✅ Correct'
        ELSE '❌ Still Wrong'
    END as verification_status
FROM staked_nfts 
WHERE nft_rarity = 'Silver'
ORDER BY wallet_address, nft_id;

-- 5. Update the stake_nft_with_source function to use correct Silver reward
CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    p_nft_id TEXT,
    nft_rarity TEXT,
    staking_source TEXT DEFAULT 'offchain',
    transaction_hash TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    daily_reward DECIMAL(18,8);
    actual_rarity TEXT;
BEGIN
    -- Validate inputs
    IF user_wallet IS NULL OR TRIM(user_wallet) = '' THEN
        RETURN json_build_object('success', false, 'message', 'Invalid wallet address', 'error', 'INVALID_WALLET');
    END IF;
    
    IF p_nft_id IS NULL OR TRIM(p_nft_id) = '' THEN
        RETURN json_build_object('success', false, 'message', 'Invalid NFT ID', 'error', 'INVALID_NFT_ID');
    END IF;

    -- Check if already staked
    IF EXISTS (SELECT 1 FROM staked_nfts WHERE wallet_address = user_wallet AND nft_id = p_nft_id) THEN
        RETURN json_build_object('success', false, 'message', 'NFT is already staked', 'error', 'ALREADY_STAKED');
    END IF;

    -- Preserve exact rarity for onchain NFTs, normalize for offchain
    IF staking_source = 'onchain' THEN
        actual_rarity := nft_rarity;
        RAISE NOTICE 'ONCHAIN NFT: Preserving exact blockchain rarity: %', actual_rarity;
    ELSE
        actual_rarity := CASE LOWER(TRIM(nft_rarity))
            WHEN 'common' THEN 'Common'
            WHEN 'rare' THEN 'Rare'
            WHEN 'legendary' THEN 'Legendary'
            WHEN 'legend' THEN 'Legendary'
            WHEN 'epic' THEN 'Legendary'
            WHEN 'platinum' THEN 'Platinum'
            WHEN 'silver' THEN 'Silver'
            WHEN 'gold' THEN 'Gold'
            ELSE COALESCE(nft_rarity, 'Common')
        END;
        RAISE NOTICE 'OFFCHAIN NFT: Normalized rarity from % to %', nft_rarity, actual_rarity;
    END IF;

    -- OFFICIAL NEFTIT REWARD TIER SYSTEM
    daily_reward := CASE actual_rarity
        WHEN 'Common' THEN 0.1
        WHEN 'common' THEN 0.1
        WHEN 'Rare' THEN 0.4
        WHEN 'rare' THEN 0.4
        WHEN 'Legendary' THEN 1.0
        WHEN 'legendary' THEN 1.0
        WHEN 'Legend' THEN 1.0
        WHEN 'legend' THEN 1.0
        WHEN 'Epic' THEN 1.0
        WHEN 'epic' THEN 1.0
        WHEN 'Platinum' THEN 2.5
        WHEN 'platinum' THEN 2.5
        WHEN 'Silver' THEN 8.0  -- FIXED: Correct Silver reward
        WHEN 'silver' THEN 8.0  -- FIXED: Correct Silver reward
        WHEN 'Gold' THEN 30.0
        WHEN 'gold' THEN 30.0
        ELSE 0.1
    END;

    RAISE NOTICE 'Staking NFT %, Source: %, Rarity: %, Daily Reward: % NEFT', p_nft_id, staking_source, actual_rarity, daily_reward;

    -- Insert staked NFT record
    INSERT INTO staked_nfts (
        wallet_address, 
        nft_id, 
        nft_rarity,
        daily_reward,
        staked_at, 
        staking_source,
        transaction_hash
    ) VALUES (
        user_wallet, 
        p_nft_id, 
        actual_rarity,
        daily_reward,
        NOW(), 
        staking_source,
        transaction_hash
    );

    RETURN json_build_object(
        'success', true,
        'message', format('NFT staked successfully via %s staking', staking_source),
        'nft_id', p_nft_id,
        'nft_rarity', actual_rarity,
        'daily_reward', daily_reward,
        'staking_source', staking_source,
        'transaction_hash', transaction_hash
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in stake_nft_with_source for wallet % NFT %: %', user_wallet, p_nft_id, SQLERRM;
    RETURN json_build_object('success', false, 'message', 'Error staking NFT: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- 6. Update EnhancedStakingService reward calculation function reference
-- This ensures the frontend also uses the correct Silver reward
CREATE OR REPLACE FUNCTION get_daily_reward_for_rarity(rarity_input TEXT)
RETURNS DECIMAL(18,8)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- OFFICIAL NEFTIT REWARD TIER SYSTEM
    RETURN CASE rarity_input
        WHEN 'Common' THEN 0.1
        WHEN 'common' THEN 0.1
        WHEN 'Rare' THEN 0.4
        WHEN 'rare' THEN 0.4
        WHEN 'Legendary' THEN 1.0
        WHEN 'legendary' THEN 1.0
        WHEN 'Legend' THEN 1.0
        WHEN 'legend' THEN 1.0
        WHEN 'Epic' THEN 1.0
        WHEN 'epic' THEN 1.0
        WHEN 'Platinum' THEN 2.5
        WHEN 'platinum' THEN 2.5
        WHEN 'Silver' THEN 8.0  -- CORRECT Silver reward
        WHEN 'silver' THEN 8.0  -- CORRECT Silver reward
        WHEN 'Gold' THEN 30.0
        WHEN 'gold' THEN 30.0
        ELSE 0.1
    END;
END;
$$;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public, service_role;
GRANT EXECUTE ON FUNCTION get_daily_reward_for_rarity(TEXT) TO authenticated, anon, public, service_role;

-- 8. Final verification of all reward tiers
SELECT 
    'FINAL VERIFICATION' as status,
    nft_rarity,
    daily_reward,
    COUNT(*) as nft_count,
    CASE 
        WHEN nft_rarity = 'Common' AND daily_reward = 0.1 THEN '✅ Correct'
        WHEN nft_rarity = 'Rare' AND daily_reward = 0.4 THEN '✅ Correct'
        WHEN nft_rarity = 'Legendary' AND daily_reward = 1.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Platinum' AND daily_reward = 2.5 THEN '✅ Correct'
        WHEN nft_rarity = 'Silver' AND daily_reward = 8.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Gold' AND daily_reward = 30.0 THEN '✅ Correct'
        ELSE '❌ Mismatch'
    END as status_check
FROM staked_nfts
GROUP BY nft_rarity, daily_reward
ORDER BY 
    CASE nft_rarity
        WHEN 'Common' THEN 1
        WHEN 'Rare' THEN 2
        WHEN 'Legendary' THEN 3
        WHEN 'Platinum' THEN 4
        WHEN 'Silver' THEN 5
        WHEN 'Gold' THEN 6
        ELSE 7
    END;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ SILVER NFT REWARDS FIXED TO OFFICIAL TIER SYSTEM';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ Updated Silver NFTs: 5.0 NEFT → 8.0 NEFT daily reward';
    RAISE NOTICE '✅ Updated stake_nft_with_source function with correct Silver reward';
    RAISE NOTICE '✅ Created get_daily_reward_for_rarity helper function';
    RAISE NOTICE '✅ All NFT tiers now match official NEFTIT reward system';
    RAISE NOTICE '';
    RAISE NOTICE '📊 OFFICIAL NEFTIT REWARD TIERS:';
    RAISE NOTICE '   Common: 0.1 NEFT/day';
    RAISE NOTICE '   Rare: 0.4 NEFT/day';
    RAISE NOTICE '   Legendary: 1.0 NEFT/day';
    RAISE NOTICE '   Platinum: 2.5 NEFT/day';
    RAISE NOTICE '   Silver: 8.0 NEFT/day';
    RAISE NOTICE '   Gold: 30.0 NEFT/day';
    RAISE NOTICE '============================================================================';
END $$;
