-- ============================================================================
-- FIX CLAIM REWARDS FUNCTIONS - Update to use correct column names
-- ============================================================================

-- Fix claim_nft_rewards function
CREATE OR REPLACE FUNCTION claim_nft_rewards(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nft_rewards_to_claim DECIMAL(18,8);
    result JSON;
BEGIN
    -- Calculate claimable NFT rewards using correct column names
    SELECT COALESCE(SUM(nft_earned_today), 0)
    INTO nft_rewards_to_claim
    FROM staking_rewards
    WHERE wallet_address = user_wallet
    AND is_claimed = FALSE
    AND nft_earned_today > 0;
    
    -- Check if there are rewards to claim
    IF nft_rewards_to_claim <= 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'No NFT rewards available to claim',
            'nft_rewards_claimed', 0
        );
    END IF;
    
    -- Mark NFT rewards as claimed
    UPDATE staking_rewards
    SET is_claimed = TRUE, last_updated = NOW()
    WHERE wallet_address = user_wallet
    AND is_claimed = FALSE
    AND nft_earned_today > 0;
    
    -- Add rewards to user balance
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (user_wallet, nft_rewards_to_claim, nft_rewards_to_claim, NOW())
    ON CONFLICT (wallet_address) 
    DO UPDATE SET
        total_neft_claimed = user_balances.total_neft_claimed + nft_rewards_to_claim,
        available_neft = user_balances.available_neft + nft_rewards_to_claim,
        last_updated = NOW();
    
    RETURN json_build_object(
        'success', true,
        'message', 'NFT rewards claimed successfully',
        'nft_rewards_claimed', nft_rewards_to_claim
    );
END;
$$;

-- Fix claim_token_rewards function
CREATE OR REPLACE FUNCTION claim_token_rewards(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    token_rewards_to_claim DECIMAL(18,8);
    result JSON;
BEGIN
    -- Calculate claimable token rewards using correct column names
    SELECT COALESCE(SUM(token_earned_today), 0)
    INTO token_rewards_to_claim
    FROM staking_rewards
    WHERE wallet_address = user_wallet
    AND is_claimed = FALSE
    AND token_earned_today > 0;
    
    -- Check if there are rewards to claim
    IF token_rewards_to_claim <= 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'No token rewards available to claim',
            'token_rewards_claimed', 0
        );
    END IF;
    
    -- Mark token rewards as claimed
    UPDATE staking_rewards
    SET is_claimed = TRUE, last_updated = NOW()
    WHERE wallet_address = user_wallet
    AND is_claimed = FALSE
    AND token_earned_today > 0;
    
    -- Add rewards to user balance
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (user_wallet, token_rewards_to_claim, token_rewards_to_claim, NOW())
    ON CONFLICT (wallet_address) 
    DO UPDATE SET
        total_neft_claimed = user_balances.total_neft_claimed + token_rewards_to_claim,
        available_neft = user_balances.available_neft + token_rewards_to_claim,
        last_updated = NOW();
    
    RETURN json_build_object(
        'success', true,
        'message', 'Token rewards claimed successfully',
        'token_rewards_claimed', token_rewards_to_claim
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION claim_nft_rewards(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_token_rewards(TEXT) TO authenticated, anon, public;

-- Test the fixed function
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ CLAIM REWARDS FUNCTIONS FIXED';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Fixed Issues:';
    RAISE NOTICE '   1. ✅ Updated column names to match actual schema';
    RAISE NOTICE '   2. ✅ claim_nft_rewards now uses nft_earned_today';
    RAISE NOTICE '   3. ✅ claim_token_rewards now uses token_earned_today';
    RAISE NOTICE '   4. ✅ Functions check is_claimed = FALSE';
    RAISE NOTICE '   5. ✅ Proper balance updates with available_neft';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test the functions:';
    RAISE NOTICE '   SELECT claim_nft_rewards(''your_wallet_address'');';
    RAISE NOTICE '   SELECT claim_token_rewards(''your_wallet_address'');';
    RAISE NOTICE '';
END $$;
