-- ============================================================================
-- FIX: Onchain NFT Rarity Storage Issue
-- ============================================================================
-- Problem: Database function stores wrong rarity and daily reward for onchain NFTs
-- Solution: Fix function to preserve exact rarity and calculate correct rewards

-- 1. Fix the stake_nft_with_source function to preserve exact rarity
CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    p_nft_id TEXT,  -- Use p_nft_id to avoid parameter conflicts
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

    -- CRITICAL FIX: Preserve exact rarity for onchain NFTs, normalize for offchain
    IF staking_source = 'onchain' THEN
        -- For onchain NFTs, preserve the exact blockchain rarity
        actual_rarity := nft_rarity;
        RAISE NOTICE 'ONCHAIN NFT: Preserving exact blockchain rarity: %', actual_rarity;
    ELSE
        -- For offchain NFTs, normalize the rarity
        actual_rarity := CASE LOWER(TRIM(nft_rarity))
            WHEN 'common' THEN 'Common'
            WHEN 'rare' THEN 'Rare'
            WHEN 'legendary' THEN 'Legendary'
            WHEN 'legend' THEN 'Legendary'
            WHEN 'epic' THEN 'Legendary'
            WHEN 'platinum' THEN 'Platinum'
            WHEN 'silver' THEN 'Silver'
            WHEN 'gold' THEN 'Gold'
            ELSE COALESCE(nft_rarity, 'Common') -- Preserve unknown rarities or default to Common
        END;
        RAISE NOTICE 'OFFCHAIN NFT: Normalized rarity from % to %', nft_rarity, actual_rarity;
    END IF;

    -- Calculate daily reward based on actual rarity (case-sensitive for onchain)
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
        ELSE 0.1 -- Default to common reward
    END;

    RAISE NOTICE 'Staking NFT %, Source: %, Actual Rarity: %, Daily Reward: %', p_nft_id, staking_source, actual_rarity, daily_reward;

    -- Insert staked NFT record with correct rarity and reward
    INSERT INTO staked_nfts (
        wallet_address, 
        nft_id, 
        nft_rarity,        -- Store the actual preserved/normalized rarity
        daily_reward,      -- Store the calculated daily reward
        staked_at, 
        staking_source,
        transaction_hash
    ) VALUES (
        user_wallet, 
        p_nft_id, 
        actual_rarity,     -- Use actual_rarity instead of original parameter
        daily_reward,      -- Use calculated daily_reward
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public, service_role;

-- 2. Fix existing wrong data for onchain NFT token ID 56
-- Based on your data, this NFT should be "Rare" with 0.4 NEFT daily reward
DO $$
DECLARE
    target_wallet TEXT := '0x33B808d4e4D959a78760f96aBB30369dD185F35C';
    target_nft_id TEXT := 'onchain_56';
    correct_rarity TEXT := 'Rare';
    correct_daily_reward DECIMAL(18,8) := 0.4;
BEGIN
    -- Update the existing staked NFT record with correct rarity and daily reward
    UPDATE staked_nfts 
    SET 
        nft_rarity = correct_rarity,
        daily_reward = correct_daily_reward
    WHERE wallet_address = target_wallet 
    AND nft_id = target_nft_id 
    AND staking_source = 'onchain';
    
    IF FOUND THEN
        RAISE NOTICE '✅ Fixed onchain NFT % for wallet %', target_nft_id, target_wallet;
        RAISE NOTICE '   Updated rarity: Common → %', correct_rarity;
        RAISE NOTICE '   Updated daily reward: 0.1 → % NEFT', correct_daily_reward;
    ELSE
        RAISE NOTICE '⚠️ No matching onchain NFT found for wallet % NFT %', target_wallet, target_nft_id;
    END IF;
END $$;

-- 3. Create a function to fix any other onchain NFTs with wrong rarity
CREATE OR REPLACE FUNCTION fix_onchain_nft_rarities()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    fixed_count INTEGER := 0;
    nft_record RECORD;
BEGIN
    -- Find all onchain NFTs that might have wrong rarity (Common with high daily_rate)
    FOR nft_record IN 
        SELECT wallet_address, nft_id, nft_rarity, daily_reward, daily_rate
        FROM staked_nfts 
        WHERE staking_source = 'onchain' 
        AND nft_rarity = 'Common' 
        AND (daily_rate > 0.4 OR daily_reward != daily_rate)
    LOOP
        -- Determine correct rarity based on daily_rate
        DECLARE
            correct_rarity TEXT;
            correct_daily_reward DECIMAL(18,8);
        BEGIN
            correct_daily_reward := nft_record.daily_rate;
            
            correct_rarity := CASE 
                WHEN correct_daily_reward <= 0.1 THEN 'Common'
                WHEN correct_daily_reward <= 0.4 THEN 'Rare'
                WHEN correct_daily_reward <= 1.0 THEN 'Legendary'
                WHEN correct_daily_reward <= 2.5 THEN 'Platinum'
                WHEN correct_daily_reward <= 8.0 THEN 'Silver'
                WHEN correct_daily_reward <= 30.0 THEN 'Gold'
                ELSE 'Legendary' -- Default for very high values
            END;
            
            -- Update the record
            UPDATE staked_nfts 
            SET 
                nft_rarity = correct_rarity,
                daily_reward = correct_daily_reward
            WHERE wallet_address = nft_record.wallet_address 
            AND nft_id = nft_record.nft_id;
            
            fixed_count := fixed_count + 1;
            RAISE NOTICE 'Fixed NFT %: % → %, Daily: % NEFT', 
                nft_record.nft_id, nft_record.nft_rarity, correct_rarity, correct_daily_reward;
        END;
    END LOOP;
    
    RETURN format('Fixed %s onchain NFTs with incorrect rarity data', fixed_count);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION fix_onchain_nft_rarities() TO authenticated, anon, public, service_role;

-- 4. Run the fix for existing data
SELECT fix_onchain_nft_rarities();

-- 5. Verification query to check the fix
SELECT 
    'VERIFICATION' as check_type,
    wallet_address,
    nft_id,
    nft_rarity,
    daily_reward,
    daily_rate,
    staking_source,
    CASE 
        WHEN nft_rarity = 'Common' AND daily_reward = 0.1 THEN '✅ Correct'
        WHEN nft_rarity = 'Rare' AND daily_reward = 0.4 THEN '✅ Correct'
        WHEN nft_rarity = 'Legendary' AND daily_reward = 1.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Platinum' AND daily_reward = 2.5 THEN '✅ Correct'
        WHEN nft_rarity = 'Silver' AND daily_reward = 8.0 THEN '✅ Correct'
        WHEN nft_rarity = 'Gold' AND daily_reward = 30.0 THEN '✅ Correct'
        ELSE '❌ Mismatch'
    END as status
FROM staked_nfts 
WHERE staking_source = 'onchain'
ORDER BY wallet_address, nft_id;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ ONCHAIN NFT RARITY STORAGE FIX COMPLETED';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '✅ Fixed stake_nft_with_source function to preserve onchain NFT rarity';
    RAISE NOTICE '✅ Updated existing wrong data for onchain NFT token_56';
    RAISE NOTICE '✅ Created fix_onchain_nft_rarities() function for future corrections';
    RAISE NOTICE '🎯 Onchain NFTs will now store correct rarity and daily rewards!';
    RAISE NOTICE '============================================================================';
END $$;
