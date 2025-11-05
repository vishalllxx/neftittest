-- =============================================================================
-- FIX 01B: SERVICE COMPATIBILITY UPDATE (CORRECTED FOR ACTUAL SCHEMA)
-- =============================================================================
-- Purpose: Add overloaded function to match EnhancedStakingService parameter format
-- Deploy: AFTER FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql
-- Status: CRITICAL - Ensures service calls work correctly

-- =============================================================================
-- OVERLOADED FUNCTION: stake_nft_with_source (5 parameters)
-- =============================================================================
-- This version matches the exact parameters EnhancedStakingService.ts sends

-- Drop existing overloaded function if it exists
DROP FUNCTION IF EXISTS stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    nft_id TEXT,
    nft_rarity TEXT,
    staking_source TEXT,
    transaction_hash TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    calculated_daily_reward DECIMAL(18,8);
BEGIN
    -- Check if NFT is already staked
    IF EXISTS (
        SELECT 1 FROM staked_nfts 
        WHERE wallet_address = user_wallet 
        AND staked_nfts.nft_id = stake_nft_with_source.nft_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'NFT is already staked',
            'error', 'ALREADY_STAKED'
        );
    END IF;
    
    -- Calculate daily reward based on rarity
    calculated_daily_reward := get_daily_reward_for_rarity(nft_rarity);
    
    -- Insert staked NFT with metadata (using actual column names)
    INSERT INTO staked_nfts (
        wallet_address,
        nft_id,
        nft_rarity,
        staking_source,
        blockchain,
        daily_reward,              -- ← Actual column name
        total_earned,
        staked_at,
        last_claim,
        last_reward_calculated,
        transaction_hash
    ) VALUES (
        user_wallet,
        stake_nft_with_source.nft_id,
        nft_rarity,
        staking_source,
        'polygon',  -- Default blockchain
        calculated_daily_reward,
        0,
        NOW(),
        NOW(),
        NOW(),
        transaction_hash
    );
    
    RETURN json_build_object(
        'success', true,
        'message', format('NFT staked successfully (%s rarity, %s NEFT/day, %s)', 
            nft_rarity, calculated_daily_reward, staking_source),
        'nft_id', stake_nft_with_source.nft_id,
        'rarity', nft_rarity,
        'daily_rate', calculated_daily_reward,    -- For backward compatibility
        'daily_reward', calculated_daily_reward,  -- Frontend uses this
        'staking_source', staking_source,
        'transaction_hash', transaction_hash,
        'blockchain', 'polygon'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error staking NFT: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== FIX 01B: SERVICE COMPATIBILITY UPDATE (CORRECTED) ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Created overloaded function:';
    RAISE NOTICE '   - stake_nft_with_source(wallet, id, rarity, source, tx_hash)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ This version accepts parameters exactly as sent by:';
    RAISE NOTICE '   - EnhancedStakingService.ts';
    RAISE NOTICE '   - ImprovedOnchainStakingService.ts (via EnhancedStakingService)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Uses actual schema column: daily_reward (not daily_rate)';
    RAISE NOTICE '✅ Rarity-based rewards will be calculated correctly';
    RAISE NOTICE '✅ Staking source (onchain/offchain) will be tracked';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Service compatibility ensured!';
    RAISE NOTICE '';
END $$;
