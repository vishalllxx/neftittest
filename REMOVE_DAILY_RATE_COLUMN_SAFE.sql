-- ============================================================================
-- SAFELY REMOVE DAILY_RATE COLUMN - PRESERVE CORRECT RARITY-BASED REWARDS
-- ============================================================================
-- This version preserves correct daily_reward values based on rarity tiers

-- 1. First, let's check current data (daily_rate column already dropped)
SELECT 
    'BEFORE CLEANUP' as status,
    nft_id,
    nft_rarity,
    daily_reward,
    CASE 
        WHEN nft_rarity = 'Common' AND daily_reward = 0.1 THEN '✅ Correct'
        WHEN nft_rarity = 'Rare' AND daily_reward = 0.4 THEN '✅ Correct'
        WHEN nft_rarity = 'Legendary' AND daily_reward = 1.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Platinum' AND daily_reward = 2.5 THEN '✅ Correct'
        WHEN nft_rarity = 'Silver' AND daily_reward = 8.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Gold' AND daily_reward = 30.0 THEN '✅ Correct'
        ELSE '❌ Wrong - Needs Fix'
    END as reward_status
FROM staked_nfts
ORDER BY wallet_address, nft_id;

-- 2. FIX daily_reward values to match official NEFTIT rarity tiers
-- DO NOT copy from daily_rate - use correct rarity-based values
UPDATE staked_nfts 
SET daily_reward = CASE nft_rarity
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
    WHEN 'Silver' THEN 8.0
    WHEN 'silver' THEN 8.0
    WHEN 'Gold' THEN 30.0
    WHEN 'gold' THEN 30.0
    ELSE 0.1 -- Default to Common
END
WHERE daily_reward != CASE nft_rarity
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
    WHEN 'Silver' THEN 8.0
    WHEN 'silver' THEN 8.0
    WHEN 'Gold' THEN 30.0
    WHEN 'gold' THEN 30.0
    ELSE 0.1
END;

-- 3. Verify all rewards are now correct based on rarity
SELECT 
    'AFTER RARITY FIX' as status,
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
        ELSE '❌ Still Wrong'
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

-- 4. Check if daily_rate column still exists (likely already dropped)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staked_nfts' AND column_name = 'daily_rate') THEN
        ALTER TABLE staked_nfts DROP COLUMN daily_rate;
        RAISE NOTICE 'daily_rate column dropped successfully';
    ELSE
        RAISE NOTICE 'daily_rate column already does not exist - skipping drop';
    END IF;
END $$;

-- 5. Update stake_nft_with_source function (without daily_rate references)
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
        WHEN 'Silver' THEN 8.0
        WHEN 'silver' THEN 8.0
        WHEN 'Gold' THEN 30.0
        WHEN 'gold' THEN 30.0
        ELSE 0.1
    END;

    RAISE NOTICE 'Staking NFT %, Source: %, Rarity: %, Daily Reward: % NEFT', p_nft_id, staking_source, actual_rarity, daily_reward;

    -- Insert staked NFT record (no daily_rate column)
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

-- 6. Update get_staked_nfts_with_source function (remove daily_rate)
CREATE OR REPLACE FUNCTION get_staked_nfts_with_source(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(json_agg(
            json_build_object(
                'id', id,
                'wallet_address', wallet_address,
                'nft_id', nft_id,
                'nft_rarity', nft_rarity,
                'daily_reward', daily_reward,  -- Only daily_reward, no daily_rate
                'staked_at', staked_at,
                'staking_source', staking_source,
                'transaction_hash', transaction_hash,
                'last_reward_calculated', last_reward_calculated,
                'total_earned', total_earned,
                'last_claim', last_claim
            )
        ), '[]'::json)
        FROM staked_nfts
        WHERE wallet_address = user_wallet
        ORDER BY staked_at DESC
    );
END;
$$;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public, service_role;
GRANT EXECUTE ON FUNCTION get_staked_nfts_with_source(TEXT) TO authenticated, anon, public, service_role;

-- 8. Final verification - all rewards should match rarity tiers
SELECT 
    'FINAL VERIFICATION' as status,
    wallet_address,
    nft_id,
    nft_rarity,
    daily_reward,
    staking_source,
    CASE 
        WHEN nft_rarity = 'Common' AND daily_reward = 0.1 THEN '✅ Correct'
        WHEN nft_rarity = 'Rare' AND daily_reward = 0.4 THEN '✅ Correct'
        WHEN nft_rarity = 'Legendary' AND daily_reward = 1.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Platinum' AND daily_reward = 2.5 THEN '✅ Correct'
        WHEN nft_rarity = 'Silver' AND daily_reward = 8.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Gold' AND daily_reward = 30.0 THEN '✅ Correct'
        ELSE '❌ Still Wrong'
    END as status_check
FROM staked_nfts
ORDER BY wallet_address, nft_id;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ DAILY_RATE COLUMN SAFELY REMOVED WITH CORRECT REWARDS';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ Fixed all daily_reward values to match official NEFTIT rarity tiers';
    RAISE NOTICE '✅ Removed daily_rate column from staked_nfts table';
    RAISE NOTICE '✅ Updated stake_nft_with_source function';
    RAISE NOTICE '✅ Updated get_staked_nfts_with_source function';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Your Rare NFT should now show: daily_reward = 0.4 NEFT (not 5.0)';
    RAISE NOTICE '🎯 All rewards now based on official NEFTIT rarity tiers!';
    RAISE NOTICE '============================================================================';
END $$;
