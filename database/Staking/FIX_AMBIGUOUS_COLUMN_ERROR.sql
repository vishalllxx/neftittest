-- =============================================================================
-- FIX AMBIGUOUS COLUMN ERROR IN STAKING FUNCTIONS
-- =============================================================================
-- Error: column reference "reward_type" is ambiguous
-- This happens when function parameter names conflict with table column names
-- =============================================================================

-- First, let's check what your actual staking_rewards table structure looks like
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'staking_rewards'
ORDER BY ordinal_position;

-- =============================================================================
-- FIX: Update calculate_pending_rewards function to avoid ambiguity
-- =============================================================================

DROP FUNCTION IF EXISTS calculate_pending_rewards(TEXT, TEXT);

CREATE OR REPLACE FUNCTION calculate_pending_rewards(
    p_wallet_address TEXT,
    p_reward_type TEXT
)
RETURNS DECIMAL(18,8)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    pending_amount DECIMAL(18,8) := 0;
BEGIN
    -- Use parameter prefix (p_) to avoid ambiguity with column names
    IF p_reward_type = 'nft' THEN
        -- Sum up all unclaimed NFT rewards
        SELECT COALESCE(SUM(nft_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
          
    ELSIF p_reward_type = 'token' THEN
        -- Sum up all unclaimed Token rewards
        SELECT COALESCE(SUM(token_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
          
    ELSE
        -- Total pending rewards
        SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
    END IF;
    
    RETURN pending_amount;
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error calculating pending rewards for %: %', p_wallet_address, SQLERRM;
    RETURN 0;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_pending_rewards(TEXT, TEXT) TO authenticated, anon, public;

-- =============================================================================
-- FIX: Update get_user_staking_summary function
-- =============================================================================

DROP FUNCTION IF EXISTS get_user_staking_summary(TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary(p_user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staked_nfts_count INTEGER := 0;
    v_staked_tokens_amount DECIMAL(18,8) := 0;
    v_nft_pending_rewards DECIMAL(18,8) := 0;
    v_token_pending_rewards DECIMAL(18,8) := 0;
    v_daily_nft_rewards DECIMAL(18,8) := 0;
    v_daily_token_rewards DECIMAL(18,8) := 0;
BEGIN
    -- Count staked NFTs
    SELECT COUNT(*)
    INTO v_staked_nfts_count
    FROM staked_nfts
    WHERE wallet_address = p_user_wallet;
    
    -- Sum staked tokens
    SELECT COALESCE(SUM(amount), 0)
    INTO v_staked_tokens_amount
    FROM staked_tokens
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate daily NFT rewards
    SELECT COALESCE(SUM(daily_reward), 0)
    INTO v_daily_nft_rewards
    FROM staked_nfts
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate daily token rewards
    SELECT COALESCE(SUM(daily_reward), 0)
    INTO v_daily_token_rewards
    FROM staked_tokens
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate pending NFT rewards from staking_rewards table
    SELECT COALESCE(SUM(nft_earned_today), 0)
    INTO v_nft_pending_rewards
    FROM staking_rewards
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false;
    
    -- Calculate pending token rewards from staking_rewards table
    SELECT COALESCE(SUM(token_earned_today), 0)
    INTO v_token_pending_rewards
    FROM staking_rewards
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false;
    
    -- Return JSON summary
    RETURN json_build_object(
        'staked_nfts_count', v_staked_nfts_count,
        'staked_tokens_amount', v_staked_tokens_amount,
        'nft_pending_rewards', v_nft_pending_rewards,
        'token_pending_rewards', v_token_pending_rewards,
        'total_pending_rewards', v_nft_pending_rewards + v_token_pending_rewards,
        'daily_nft_rewards', v_daily_nft_rewards,
        'daily_token_rewards', v_daily_token_rewards
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in get_user_staking_summary for %: %', p_user_wallet, SQLERRM;
    RETURN json_build_object(
        'staked_nfts_count', 0,
        'staked_tokens_amount', 0,
        'nft_pending_rewards', 0,
        'token_pending_rewards', 0,
        'total_pending_rewards', 0,
        'daily_nft_rewards', 0,
        'daily_token_rewards', 0,
        'error', SQLERRM
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_staking_summary(TEXT) TO authenticated, anon, public;

-- =============================================================================
-- TEST: Verify the fix works
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Functions updated successfully!';
    RAISE NOTICE '   - calculate_pending_rewards(wallet, type)';
    RAISE NOTICE '   - get_user_staking_summary(wallet)';
    RAISE NOTICE '';
    RAISE NOTICE 'Testing with wallet: 0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
END $$;

-- Test the summary function
SELECT get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as test_result;

-- =============================================================================
-- NOW RUN THE MAIN FIX SCRIPT
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ AMBIGUOUS COLUMN ERROR FIXED!';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Next Steps:';
    RAISE NOTICE '   1. Now run the reward generation function';
    RAISE NOTICE '   2. Continue with the main fix script';
    RAISE NOTICE '';
END $$;
