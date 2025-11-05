-- ============================================================================
-- REMOVE DAILY_RATE COLUMN FROM STAKED_NFTS TABLE
-- ============================================================================
-- Remove redundant daily_rate column and keep only daily_reward

-- 1. First, let's check what data we have in both columns
SELECT 
    'BEFORE CLEANUP' as status,
    nft_id,
    nft_rarity,
    daily_reward,
    daily_rate,
    CASE 
        WHEN daily_reward = daily_rate THEN '✅ Match'
        WHEN daily_reward != daily_rate THEN '❌ Mismatch'
        WHEN daily_rate IS NULL THEN '⚠️ daily_rate NULL'
        WHEN daily_reward IS NULL THEN '⚠️ daily_reward NULL'
        ELSE '❓ Unknown'
    END as comparison
FROM staked_nfts
ORDER BY wallet_address, nft_id;

-- 2. Update daily_reward with daily_rate values where daily_reward is wrong
-- (In case daily_rate has the correct values and daily_reward is wrong)
UPDATE staked_nfts 
SET daily_reward = daily_rate 
WHERE daily_rate IS NOT NULL 
AND (daily_reward IS NULL OR daily_reward != daily_rate)
AND daily_rate > daily_reward; -- Only update if daily_rate seems more reasonable

-- 3. Check how many records were updated
SELECT 
    'AFTER SYNC' as status,
    COUNT(*) as total_records,
    COUNT(CASE WHEN daily_reward = daily_rate THEN 1 END) as matching_records,
    COUNT(CASE WHEN daily_reward != daily_rate THEN 1 END) as mismatched_records,
    COUNT(CASE WHEN daily_rate IS NULL THEN 1 END) as null_daily_rate,
    COUNT(CASE WHEN daily_reward IS NULL THEN 1 END) as null_daily_reward
FROM staked_nfts;

-- 4. Remove the daily_rate column from staked_nfts table
ALTER TABLE staked_nfts DROP COLUMN IF EXISTS daily_rate;

-- 5. Update the stake_nft_with_source function to remove daily_rate references
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

    -- Calculate daily reward based on actual rarity
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

    -- Insert staked NFT record (removed daily_rate column)
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

-- 6. Update get_staked_nfts_with_source function to remove daily_rate references
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

-- 7. Grant permissions for updated functions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public, service_role;
GRANT EXECUTE ON FUNCTION get_staked_nfts_with_source(TEXT) TO authenticated, anon, public, service_role;

-- 8. Verify the cleanup
SELECT 
    'FINAL VERIFICATION' as status,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'staked_nfts' 
AND column_name IN ('daily_reward', 'daily_rate')
ORDER BY column_name;

-- 9. Check the cleaned data
SELECT 
    'CLEANED DATA' as status,
    nft_id,
    nft_rarity,
    daily_reward,
    staking_source
FROM staked_nfts
ORDER BY wallet_address, nft_id;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ DAILY_RATE COLUMN REMOVAL COMPLETED';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ Synchronized daily_reward with daily_rate values where needed';
    RAISE NOTICE '✅ Removed daily_rate column from staked_nfts table';
    RAISE NOTICE '✅ Updated stake_nft_with_source function';
    RAISE NOTICE '✅ Updated get_staked_nfts_with_source function';
    RAISE NOTICE '🎯 Now using only daily_reward column for all reward calculations!';
    RAISE NOTICE '============================================================================';
END $$;
