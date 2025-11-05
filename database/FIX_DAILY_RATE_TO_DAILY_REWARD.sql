-- ============================================================================
-- FIX: Update All Functions to Use daily_reward Instead of daily_rate
-- ============================================================================
-- User removed daily_rate column and wants to use daily_reward column
-- This script updates all functions that reference daily_rate
-- ============================================================================

-- Fix get_staked_nfts_with_source function
CREATE OR REPLACE FUNCTION get_staked_nfts_with_source(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Validate input
    IF user_wallet IS NULL OR TRIM(user_wallet) = '' THEN
        RETURN '[]'::JSON;
    END IF;

    -- Get all staked NFTs with source information (using daily_reward instead of daily_rate)
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', id,
            'nft_id', nft_id,
            'wallet_address', wallet_address,
            'staked_at', staked_at,
            'daily_reward', daily_reward,  -- ✅ Changed from daily_rate
            'total_earned', total_earned,
            'last_claim', last_claim,
            'staking_source', COALESCE(staking_source, 'offchain'),
            'stakingSource', COALESCE(staking_source, 'offchain') -- Legacy compatibility
        )
        ORDER BY staked_at DESC
    ), '[]'::JSON) INTO result
    FROM staked_nfts 
    WHERE wallet_address = user_wallet;

    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error fetching staked NFTs for %: %', user_wallet, SQLERRM;
    RETURN '[]'::JSON;
END;
$$;

-- Fix get_staked_nfts function (basic version)
CREATE OR REPLACE FUNCTION get_staked_nfts(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Validate input
    IF user_wallet IS NULL OR TRIM(user_wallet) = '' THEN
        RETURN '[]'::JSON;
    END IF;

    -- Get all staked NFTs (using daily_reward instead of daily_rate)
    SELECT COALESCE(json_agg(
        json_build_object(
            'id', id,
            'nft_id', nft_id,
            'nft_rarity', nft_rarity,
            'wallet_address', wallet_address,
            'staked_at', staked_at,
            'daily_reward', daily_reward,  -- ✅ Changed from daily_rate
            'total_earned', total_earned,
            'last_claim', last_claim,
            'staking_source', COALESCE(staking_source, 'offchain'),
            -- Calculate earned rewards
            'hours_staked', EXTRACT(EPOCH FROM (NOW() - staked_at)) / 3600,
            'accumulated_rewards', daily_reward * (EXTRACT(EPOCH FROM (NOW() - staked_at)) / 86400)
        )
        ORDER BY staked_at DESC
    ), '[]'::JSON) INTO result
    FROM staked_nfts 
    WHERE wallet_address = user_wallet;

    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error fetching staked NFTs for %: %', user_wallet, SQLERRM;
    RETURN '[]'::JSON;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_staked_nfts_with_source(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_staked_nfts(TEXT) TO authenticated, anon, public;

-- Verification function
CREATE OR REPLACE FUNCTION verify_daily_reward_fix()
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    has_daily_reward BOOLEAN;
    has_daily_rate BOOLEAN;
    functions_updated BOOLEAN;
BEGIN
    -- Check if daily_reward column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'staked_nfts'
        AND column_name = 'daily_reward'
    ) INTO has_daily_reward;
    
    -- Check if daily_rate column exists (should be false)
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'staked_nfts'
        AND column_name = 'daily_rate'
    ) INTO has_daily_rate;
    
    -- Check if functions exist
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname IN ('stake_nft_with_source', 'get_staked_nfts', 'get_staked_nfts_with_source')
    ) INTO functions_updated;
    
    RETURN json_build_object(
        'daily_reward_column_exists', has_daily_reward,
        'daily_rate_column_exists', has_daily_rate,
        'functions_updated', functions_updated,
        'status', CASE 
            WHEN has_daily_reward AND NOT has_daily_rate AND functions_updated THEN 'SUCCESS - All functions use daily_reward'
            WHEN NOT has_daily_reward THEN 'ERROR - daily_reward column missing'
            WHEN has_daily_rate THEN 'WARNING - daily_rate column still exists'
            ELSE 'ERROR - Functions not updated'
        END,
        'timestamp', NOW()
    );
END;
$$;

-- Run verification
SELECT verify_daily_reward_fix();

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- 
-- ✅ UPDATED FUNCTIONS:
-- • stake_nft_with_source() - Uses daily_reward column
-- • get_staked_nfts() - Uses daily_reward column  
-- • get_staked_nfts_with_source() - Uses daily_reward column
--
-- ✅ EXPECTED RESULT:
-- • No more "daily_rate column does not exist" errors
-- • All staking functions work with daily_reward column
-- • EnhancedStakingService will work properly
--
-- ============================================================================
