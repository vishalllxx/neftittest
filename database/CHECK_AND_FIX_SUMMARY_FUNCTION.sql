-- CHECK AND FIX get_user_staking_summary FUNCTION
-- To work with your hybrid schema

-- ============================================================================
-- STEP 1: Check current function definition
-- ============================================================================
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'get_user_staking_summary';

-- ============================================================================
-- STEP 2: Create/Update function to work with YOUR ACTUAL SCHEMA
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_staking_summary(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    staked_nfts_count INTEGER := 0;
    staked_tokens_amount DECIMAL(18,8) := 0;
    nft_daily DECIMAL(18,8) := 0;
    token_daily DECIMAL(18,8) := 0;
    nft_pending DECIMAL(18,8) := 0;
    token_pending DECIMAL(18,8) := 0;
    total_pending DECIMAL(18,8) := 0;
BEGIN
    -- Get staked NFTs count
    SELECT COUNT(*) INTO staked_nfts_count 
    FROM staked_nfts 
    WHERE wallet_address = user_wallet;
    
    -- Get staked tokens amount
    SELECT COALESCE(SUM(amount), 0) INTO staked_tokens_amount 
    FROM staked_tokens 
    WHERE wallet_address = user_wallet;
    
    -- Get daily rewards
    SELECT COALESCE(SUM(daily_reward), 0) INTO nft_daily 
    FROM staked_nfts 
    WHERE wallet_address = user_wallet;
    
    SELECT COALESCE(SUM(daily_reward), 0) INTO token_daily 
    FROM staked_tokens 
    WHERE wallet_address = user_wallet;
    
    -- Calculate pending rewards from staking_rewards table
    -- Try NEW schema columns first (reward_type + reward_amount)
    SELECT 
        COALESCE(SUM(CASE WHEN reward_type = 'nft_staking' THEN reward_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN reward_type = 'token_staking' THEN reward_amount ELSE 0 END), 0)
    INTO nft_pending, token_pending
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND is_claimed = FALSE
    AND reward_amount IS NOT NULL;
    
    -- If no results from NEW schema, try OLD schema columns
    IF nft_pending = 0 AND token_pending = 0 THEN
        SELECT 
            COALESCE(SUM(nft_earned_today), 0),
            COALESCE(SUM(token_earned_today), 0)
        INTO nft_pending, token_pending
        FROM staking_rewards
        WHERE wallet_address = user_wallet 
        AND is_claimed = FALSE;
    END IF;
    
    total_pending := nft_pending + token_pending;
    
    -- Return JSON with BOTH naming conventions for compatibility
    RETURN json_build_object(
        'wallet_address', user_wallet,
        'staked_nfts_count', staked_nfts_count,
        'staked_tokens_amount', staked_tokens_amount,
        'daily_nft_rewards', nft_daily,
        'daily_token_rewards', token_daily,
        -- NEW naming (what UI expects after my fix)
        'nft_pending_rewards', nft_pending,
        'token_pending_rewards', token_pending,
        'total_pending_rewards', total_pending,
        -- OLD naming (for backward compatibility)
        'claimable_nft_rewards', nft_pending,
        'claimable_token_rewards', token_pending,
        'total_claimable_rewards', total_pending
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'error', SQLERRM,
        'wallet_address', user_wallet,
        'staked_nfts_count', 0,
        'staked_tokens_amount', 0,
        'nft_pending_rewards', 0,
        'token_pending_rewards', 0,
        'total_pending_rewards', 0
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_staking_summary(TEXT) TO anon, authenticated, service_role;

-- ============================================================================
-- STEP 3: Insert token rewards for your wallet
-- ============================================================================

-- Replace 'YOUR_WALLET_ADDRESS' with your actual wallet
INSERT INTO staking_rewards (
    wallet_address,
    reward_date,
    reward_type,
    source_id,
    reward_amount,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed
)
SELECT 
    wallet_address,
    CURRENT_DATE,
    'token_staking',
    id::TEXT,
    daily_reward,
    0,
    daily_reward,
    daily_reward,
    FALSE
FROM staked_tokens
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
ON CONFLICT (wallet_address, reward_date, reward_type, source_id) 
DO UPDATE SET
    reward_amount = EXCLUDED.reward_amount,
    token_earned_today = EXCLUDED.token_earned_today,
    total_earned = EXCLUDED.total_earned,
    last_updated = NOW();

-- ============================================================================
-- STEP 4: Verify everything
-- ============================================================================

-- Check inserted rewards
SELECT 
    'Rewards in table:' as check,
    wallet_address,
    reward_date,
    reward_type,
    reward_amount,
    token_earned_today,
    is_claimed
FROM staking_rewards
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
ORDER BY created_at DESC;

-- Test summary function
SELECT 
    'Summary function result:' as check,
    get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- ============================================================================
-- USAGE INSTRUCTIONS
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== COMPLETE FIX FOR YOUR SCHEMA ===';
    RAISE NOTICE '';
    RAISE NOTICE '1. Replace YOUR_WALLET_ADDRESS with your wallet (2 places)';
    RAISE NOTICE '2. Run STEP 2 to update get_user_staking_summary function';
    RAISE NOTICE '3. Run STEP 3 to insert token rewards';
    RAISE NOTICE '4. Run STEP 4 to verify';
    RAISE NOTICE '5. Refresh your staking page';
    RAISE NOTICE '';
    RAISE NOTICE 'The function now returns BOTH naming conventions:';
    RAISE NOTICE '  - token_pending_rewards (new)';
    RAISE NOTICE '  - claimable_token_rewards (old)';
    RAISE NOTICE '';
    RAISE NOTICE 'Your frontend fix will pick up either one!';
END $$;
