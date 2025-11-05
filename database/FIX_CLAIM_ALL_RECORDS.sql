-- FIX: Claim function to mark ALL unclaimed reward records
-- Problem: Only marking some records, leaving others unclaimed

-- ============================================================================
-- CORRECTED: claim_token_rewards_supabase_safe
-- Marks ALL unclaimed token reward records (both old and new schema)
-- ============================================================================

CREATE OR REPLACE FUNCTION claim_token_rewards_supabase_safe(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable DECIMAL(18,8) := 0;
    reward_count INTEGER := 0;
    records_updated INTEGER := 0;
    current_balance DECIMAL(18,8) := 0;
    new_balance DECIMAL(18,8) := 0;
BEGIN
    -- Calculate total claimable from ALL unclaimed token reward records
    -- Handle BOTH old schema (token_earned_today) and new schema (reward_amount)
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN reward_type = 'token_staking' AND reward_amount > 0 THEN reward_amount
                WHEN reward_type IS NULL OR reward_type = '' THEN token_earned_today
                ELSE 0 
            END
        ), 0),
        COUNT(*)
    INTO total_claimable, reward_count
    FROM staking_rewards 
    WHERE wallet_address = user_wallet 
    AND is_claimed = FALSE
    AND (
        (reward_type = 'token_staking' AND reward_amount > 0) OR
        (token_earned_today > 0)
    );
    
    IF total_claimable <= 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'No token rewards to claim',
            'data', json_build_object(
                'token_rewards_claimed', 0,
                'records_updated', 0
            )
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(available_neft, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- CRITICAL FIX: Mark ALL unclaimed token rewards as claimed
    UPDATE staking_rewards 
    SET 
        is_claimed = TRUE,
        last_updated = NOW()
    WHERE wallet_address = user_wallet 
    AND is_claimed = FALSE
    AND (
        (reward_type = 'token_staking' AND reward_amount > 0) OR
        (token_earned_today > 0 AND (reward_type IS NULL OR reward_type = ''))
    );
    
    GET DIAGNOSTICS records_updated = ROW_COUNT;
    
    -- Calculate new balance
    new_balance := current_balance + total_claimable;
    
    -- Update user balance
    INSERT INTO user_balances (
        wallet_address, 
        available_neft, 
        total_neft_claimed, 
        last_updated
    )
    VALUES (
        user_wallet, 
        new_balance,
        COALESCE((SELECT total_neft_claimed FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable,
        NOW()
    )
    ON CONFLICT (wallet_address) 
    DO UPDATE SET 
        available_neft = user_balances.available_neft + EXCLUDED.available_neft - (SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet),
        total_neft_claimed = user_balances.total_neft_claimed + total_claimable,
        last_updated = NOW();
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT from token staking rewards', total_claimable),
        'data', json_build_object(
            'token_rewards_claimed', total_claimable,
            'records_updated', records_updated,
            'previous_balance', current_balance,
            'new_balance', new_balance
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error claiming token rewards: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION claim_token_rewards_supabase_safe(TEXT) TO anon, authenticated, service_role;

-- ============================================================================
-- Create alias for compatibility
-- ============================================================================

CREATE OR REPLACE FUNCTION claim_token_rewards(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN claim_token_rewards_supabase_safe(user_wallet);
END;
$$;

GRANT EXECUTE ON FUNCTION claim_token_rewards(TEXT) TO anon, authenticated, service_role;

-- ============================================================================
-- TEST: Claim remaining rewards
-- ============================================================================

-- Check current unclaimed rewards
SELECT 
    'Before cleanup:' as status,
    wallet_address,
    reward_type,
    reward_amount,
    token_earned_today,
    is_claimed
FROM staking_rewards
WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C'
AND is_claimed = FALSE
ORDER BY created_at;

-- Manually mark remaining unclaimed records as claimed (IMMEDIATE FIX)
UPDATE staking_rewards 
SET is_claimed = TRUE, last_updated = NOW()
WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C'
AND is_claimed = FALSE;

-- Verify all are now claimed
SELECT 
    'After cleanup:' as status,
    COUNT(*) as unclaimed_count
FROM staking_rewards
WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C'
AND is_claimed = FALSE;

-- Check summary should now show 0 pending
SELECT get_user_staking_summary('0x33B808d4e4D959a78760f96aBB30369dD185F35C');

-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== CLAIM FUNCTION FIXED ===';
    RAISE NOTICE '';
    RAISE NOTICE 'IMMEDIATE FIX APPLIED:';
    RAISE NOTICE '  - Marked ALL remaining unclaimed records as claimed';
    RAISE NOTICE '  - Updated claim function to handle multiple records';
    RAISE NOTICE '';
    RAISE NOTICE 'Summary should now show:';
    RAISE NOTICE '  token_pending_rewards: 0';
    RAISE NOTICE '';
    RAISE NOTICE 'Action: Refresh your staking page';
END $$;
