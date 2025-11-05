-- ============================================================================
-- DEPLOY: stake_nft_with_source Function (Updated for daily_reward column)
-- ============================================================================
-- This script ensures the stake_nft_with_source function exists in your database
-- with the exact parameters that EnhancedStakingService is calling
-- 
-- IMPORTANT: Uses 'daily_reward' column instead of 'daily_rate' 
-- (User removed daily_rate column from staked_nfts table)
-- ============================================================================

-- Step 1: Drop existing function if it exists (to avoid conflicts)
DROP FUNCTION IF EXISTS stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS stake_nft_with_source CASCADE;

-- Step 2: Create the function with exact parameters from FIX_CRITICAL_STAKING_ISSUES.sql
CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    nft_id TEXT,
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
BEGIN
    -- Validate inputs
    IF user_wallet IS NULL OR TRIM(user_wallet) = '' THEN
        RETURN json_build_object('success', false, 'message', 'Invalid wallet address', 'error', 'INVALID_WALLET');
    END IF;
    
    IF nft_id IS NULL OR TRIM(nft_id) = '' THEN
        RETURN json_build_object('success', false, 'message', 'Invalid NFT ID', 'error', 'INVALID_NFT_ID');
    END IF;

    -- Check if already staked
    IF EXISTS (SELECT 1 FROM staked_nfts WHERE wallet_address = user_wallet AND staked_nfts.nft_id = stake_nft_with_source.nft_id) THEN
        RETURN json_build_object('success', false, 'message', 'NFT is already staked', 'error', 'ALREADY_STAKED');
    END IF;

    -- Calculate daily reward based on rarity
    CASE LOWER(nft_rarity)
        WHEN 'common' THEN daily_reward := 0.1;
        WHEN 'rare' THEN daily_reward := 0.4;
        WHEN 'legendary' THEN daily_reward := 1.0;
        WHEN 'platinum' THEN daily_reward := 2.5;
        WHEN 'silver' THEN daily_reward := 8.0;
        WHEN 'gold' THEN daily_reward := 30.0;
        ELSE daily_reward := 0.1; -- Default to common
    END CASE;

    -- Insert staked NFT record (using daily_reward column instead of daily_rate)
    INSERT INTO staked_nfts (
        wallet_address, 
        nft_id, 
        staked_at, 
        daily_reward, 
        total_earned, 
        last_claim,
        staking_source
    ) VALUES (
        user_wallet, 
        nft_id, 
        NOW(), 
        daily_reward, 
        0, 
        NOW(),
        staking_source
    );

    RETURN json_build_object(
        'success', true,
        'message', format('NFT staked successfully via %s staking', staking_source),
        'nft_id', nft_id,
        'daily_reward', daily_reward,
        'staking_source', staking_source,
        'transaction_hash', transaction_hash
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error staking NFT: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- Step 3: Grant permissions
GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, public;

-- Step 4: Verification
CREATE OR REPLACE FUNCTION verify_stake_function()
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    function_exists BOOLEAN;
    param_count INTEGER;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'stake_nft_with_source'
    ) INTO function_exists;
    
    -- Get parameter count
    SELECT array_length(p.proargtypes, 1) INTO param_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'stake_nft_with_source'
    LIMIT 1;
    
    RETURN json_build_object(
        'function_exists', function_exists,
        'parameter_count', COALESCE(param_count, 0),
        'expected_parameters', 5,
        'status', CASE 
            WHEN function_exists AND param_count = 5 THEN 'SUCCESS - Function ready'
            WHEN function_exists AND param_count != 5 THEN 'WARNING - Wrong parameter count'
            ELSE 'ERROR - Function missing'
        END,
        'timestamp', NOW()
    );
END;
$$;

-- Run verification
SELECT verify_stake_function();

-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS
-- ============================================================================
-- 
-- 1. Copy this entire script
-- 2. Go to Supabase SQL Editor
-- 3. Paste and run the script
-- 4. Check the verification result at the bottom
-- 5. Should show: "SUCCESS - Function ready"
-- 
-- After deployment, your EnhancedStakingService should work with:
-- - user_wallet: TEXT
-- - nft_id: TEXT  
-- - nft_rarity: TEXT
-- - staking_source: TEXT (default 'offchain')
-- - transaction_hash: TEXT (default NULL)
-- 
-- ============================================================================
