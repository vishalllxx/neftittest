-- =============================================================================
-- FIX 01: SCHEMA UPDATES AND MISSING FUNCTIONS (CORRECTED FOR ACTUAL SCHEMA)
-- =============================================================================
-- Purpose: Add missing functions for actual staked_nfts schema
-- Deploy: FIRST (before other fix files)
-- Status: CRITICAL - Corrected to match actual database schema

-- =============================================================================
-- IMPORTANT: Your actual schema already has:
-- - nft_rarity column ✅
-- - staking_source column ✅
-- - blockchain column ✅
-- - daily_reward column (NOT daily_rate!) ✅
-- - transaction_hash column ✅
-- =============================================================================

-- =============================================================================
-- PART 1: NO SCHEMA CHANGES NEEDED
-- =============================================================================
-- Your schema already has all necessary columns!
-- Skipping ALTER TABLE statements

-- =============================================================================
-- PART 2: RARITY-BASED REWARD CALCULATION FUNCTION
-- =============================================================================

-- Drop existing function if it exists (handles parameter name changes)
DROP FUNCTION IF EXISTS get_daily_reward_for_rarity(TEXT);

CREATE OR REPLACE FUNCTION get_daily_reward_for_rarity(rarity TEXT)
RETURNS DECIMAL(18,8)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Normalize rarity (handle case variations)
    CASE LOWER(TRIM(rarity))
        WHEN 'common' THEN RETURN 0.1;
        WHEN 'rare' THEN RETURN 0.4;
        WHEN 'legendary', 'legend' THEN RETURN 1.0;
        WHEN 'platinum' THEN RETURN 2.5;
        WHEN 'silver' THEN RETURN 8.0;
        WHEN 'gold' THEN RETURN 30.0;
        ELSE 
            -- Default to Common tier for unknown rarities
            RETURN 0.1;
    END CASE;
END;
$$;

-- =============================================================================
-- PART 3: ENHANCED STAKE NFT FUNCTION (Matches Actual Schema)
-- =============================================================================

-- Drop existing function if it exists (handles signature changes)
DROP FUNCTION IF EXISTS stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    nft_id TEXT,
    nft_name TEXT DEFAULT '',  -- Not stored in DB, just for response
    nft_image TEXT DEFAULT '', -- Not stored in DB, just for response
    nft_rarity TEXT DEFAULT 'Common',
    staking_source TEXT DEFAULT 'offchain',
    blockchain TEXT DEFAULT 'polygon'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    calculated_daily_reward DECIMAL(18,8);
    result JSON;
BEGIN
    -- Check if NFT is already staked
    IF EXISTS (
        SELECT 1 FROM staked_nfts 
        WHERE wallet_address = user_wallet 
        AND nft_id = stake_nft_with_source.nft_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'NFT is already staked',
            'error', 'ALREADY_STAKED'
        );
    END IF;
    
    -- Calculate daily reward based on rarity
    calculated_daily_reward := get_daily_reward_for_rarity(nft_rarity);
    
    -- Insert staked NFT (using actual column names from your schema)
    INSERT INTO staked_nfts (
        wallet_address,
        nft_id,
        nft_rarity,
        staking_source,
        blockchain,
        daily_reward,              -- ← Your actual column name
        total_earned,
        staked_at,
        last_claim,
        last_reward_calculated     -- ← Your actual column name
    ) VALUES (
        user_wallet,
        stake_nft_with_source.nft_id,
        nft_rarity,
        staking_source,
        blockchain,
        calculated_daily_reward,
        0,
        NOW(),
        NOW(),
        NOW()
    );
    
    RETURN json_build_object(
        'success', true,
        'message', format('NFT staked successfully (%s rarity, %s NEFT/day)', nft_rarity, calculated_daily_reward),
        'nft_id', stake_nft_with_source.nft_id,
        'rarity', nft_rarity,
        'daily_rate', calculated_daily_reward,      -- For backward compatibility
        'daily_reward', calculated_daily_reward,    -- Frontend uses this
        'staking_source', staking_source,
        'blockchain', blockchain
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error staking NFT: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- PART 4: GET STAKED NFTs WITH SOURCE (Matches Actual Schema)
-- =============================================================================

-- Drop existing function if it exists (handles signature changes)
DROP FUNCTION IF EXISTS get_staked_nfts_with_source(TEXT);

CREATE OR REPLACE FUNCTION get_staked_nfts_with_source(user_wallet TEXT)
RETURNS TABLE(
    id UUID,
    nft_id TEXT,
    nft_rarity TEXT,
    staking_source TEXT,
    blockchain TEXT,
    staked_at TIMESTAMP WITH TIME ZONE,
    daily_reward DECIMAL(18,8),
    total_earned DECIMAL(18,8),
    last_claim TIMESTAMP WITH TIME ZONE,
    last_reward_calculated TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    days_staked INTEGER,
    pending_rewards DECIMAL(18,8)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sn.id,
        sn.nft_id,
        sn.nft_rarity,
        sn.staking_source,
        COALESCE(sn.blockchain, 'polygon') as blockchain,
        sn.staked_at,
        sn.daily_reward,
        sn.total_earned,
        sn.last_claim,
        sn.last_reward_calculated,
        sn.transaction_hash,
        EXTRACT(DAY FROM (NOW() - sn.staked_at))::INTEGER as days_staked,
        -- Calculate real-time pending rewards since last claim
        (EXTRACT(EPOCH FROM (NOW() - sn.last_claim)) / 86400.0 * sn.daily_reward)::DECIMAL(18,8) as pending_rewards
    FROM staked_nfts sn
    WHERE sn.wallet_address = user_wallet
    ORDER BY sn.staked_at DESC;
END;
$$;

-- =============================================================================
-- PART 5: UPDATE ORIGINAL STAKE_NFT FUNCTION TO USE RARITY
-- =============================================================================

CREATE OR REPLACE FUNCTION stake_nft(
    user_wallet TEXT,
    nft_id TEXT,
    nft_name TEXT DEFAULT '',
    nft_image TEXT DEFAULT '',
    nft_rarity TEXT DEFAULT 'Common'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the enhanced version with default offchain source
    RETURN stake_nft_with_source(
        user_wallet,
        nft_id,
        nft_name,
        nft_image,
        nft_rarity,
        'offchain',
        'polygon'
    );
END;
$$;

-- =============================================================================
-- PART 6: ALIAS FUNCTIONS FOR SERVICE COMPATIBILITY
-- =============================================================================

-- Drop existing alias functions if they exist
DROP FUNCTION IF EXISTS stake_neft_tokens(TEXT, DECIMAL);
DROP FUNCTION IF EXISTS unstake_neft_tokens(TEXT, UUID, DECIMAL);

-- Alias for stake_neft_tokens -> stake_tokens
CREATE OR REPLACE FUNCTION stake_neft_tokens(user_wallet TEXT, stake_amount DECIMAL(18,8))
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN stake_tokens(user_wallet, stake_amount);
END;
$$;

-- Alias for unstake_neft_tokens -> unstake_tokens
CREATE OR REPLACE FUNCTION unstake_neft_tokens(user_wallet TEXT, staked_tokens_id UUID, unstake_amount DECIMAL(18,8))
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN unstake_tokens(user_wallet, staked_tokens_id, unstake_amount);
END;
$$;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_daily_reward_for_rarity(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_staked_nfts_with_source(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION stake_nft(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION stake_neft_tokens(TEXT, DECIMAL) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION unstake_neft_tokens(TEXT, UUID, DECIMAL) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
DECLARE
    common_rate DECIMAL(18,8);
    gold_rate DECIMAL(18,8);
BEGIN
    -- Test reward rate function
    common_rate := get_daily_reward_for_rarity('Common');
    gold_rate := get_daily_reward_for_rarity('Gold');
    
    RAISE NOTICE '';
    RAISE NOTICE '=== FIX 01: SCHEMA AND FUNCTIONS (CORRECTED) ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Schema Status:';
    RAISE NOTICE '   - All required columns already exist in staked_nfts';
    RAISE NOTICE '   - No schema changes needed';
    RAISE NOTICE '';
    RAISE NOTICE '✅ New Functions:';
    RAISE NOTICE '   - get_daily_reward_for_rarity(rarity)';
    RAISE NOTICE '   - stake_nft_with_source(wallet, id, name, image, rarity, source, blockchain)';
    RAISE NOTICE '   - get_staked_nfts_with_source(wallet)';
    RAISE NOTICE '   - stake_neft_tokens(wallet, amount) [alias]';
    RAISE NOTICE '   - unstake_neft_tokens(wallet, id, amount) [alias]';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated Functions:';
    RAISE NOTICE '   - stake_nft() now accepts rarity parameter';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Reward Rate Verification:';
    RAISE NOTICE '   - Common NFT: % NEFT/day', common_rate;
    RAISE NOTICE '   - Gold NFT: % NEFT/day', gold_rate;
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANT: Functions use daily_reward column (not daily_rate)';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_02_REWARD_GENERATION_CORRECTED.sql';
    RAISE NOTICE '';
END $$;
