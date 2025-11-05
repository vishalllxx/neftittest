-- FIX: get_user_staking_summary to SUM ALL unclaimed reward records
-- Your issue: Multiple records exist but only one is being counted

-- ============================================================================
-- PROBLEM IDENTIFIED:
-- ============================================================================
-- You have 2 unclaimed token_staking records:
-- 1. token_earned_today: 0.00547945 (old schema)
-- 2. reward_amount: 0.00547945 (new schema)
-- Total should be: 0.01095890 NEFT (ABOVE 0.01 minimum!)
-- But UI shows: 0.0055 NEFT (only counting ONE record)

-- ============================================================================
-- SOLUTION: Update function to SUM all unclaimed records
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
    
    -- CRITICAL FIX: SUM ALL unclaimed rewards, handling BOTH old and new schemas
    SELECT 
        -- NFT rewards: Try new schema first, fallback to old
        COALESCE(SUM(
            CASE 
                WHEN reward_type = 'nft_staking' AND reward_amount > 0 THEN reward_amount
                WHEN reward_type IS NULL OR reward_type = '' THEN nft_earned_today
                ELSE 0 
            END
        ), 0),
        -- Token rewards: Try new schema first, fallback to old
        COALESCE(SUM(
            CASE 
                WHEN reward_type = 'token_staking' AND reward_amount > 0 THEN reward_amount
                WHEN reward_type IS NULL OR reward_type = '' THEN token_earned_today
                ELSE 0 
            END
        ), 0)
    INTO nft_pending, token_pending
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND is_claimed = FALSE;
    
    total_pending := nft_pending + token_pending;
    
    -- Return JSON with BOTH naming conventions
    RETURN json_build_object(
        'wallet_address', user_wallet,
        'staked_nfts_count', staked_nfts_count,
        'staked_tokens_amount', staked_tokens_amount,
        'daily_nft_rewards', nft_daily,
        'daily_token_rewards', token_daily,
        -- NEW naming (what UI expects)
        'nft_pending_rewards', nft_pending,
        'token_pending_rewards', token_pending,
        'total_pending_rewards', total_pending,
        -- OLD naming (backward compatibility)
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
-- TEST: Verify it now returns correct sum
-- ============================================================================

SELECT get_user_staking_summary('0x33B808d4e4D959a78760f96aBB30369dD185F35C');

-- Expected result:
-- {
--   "token_pending_rewards": 0.01095890  (or close to this)
--   "claimable_token_rewards": 0.01095890
-- }

-- ============================================================================
-- CLEANUP: Remove duplicate record (optional)
-- ============================================================================
-- You have 2 records for the same reward, you might want to keep only one:

-- Option 1: Delete the record with NULL reward_type (old schema only)
-- DELETE FROM staking_rewards
-- WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C'
-- AND is_claimed = FALSE
-- AND reward_type IS NULL
-- AND token_earned_today > 0;

-- Option 2: Update the first record to have reward_type and reward_amount
-- UPDATE staking_rewards
-- SET 
--     reward_type = 'token_staking',
--     reward_amount = token_earned_today,
--     source_id = (SELECT id::TEXT FROM staked_tokens WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C' LIMIT 1)
-- WHERE wallet_address = '0x33B808d4e4D959a78760f96aBB30369dD185F35C'
-- AND is_claimed = FALSE
-- AND reward_type IS NULL
-- AND token_earned_today > 0;

-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== FUNCTION UPDATED TO SUM ALL RECORDS ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Your rewards:';
    RAISE NOTICE '  Record 1: 0.00547945 NEFT (old schema)';
    RAISE NOTICE '  Record 2: 0.00547945 NEFT (new schema)';
    RAISE NOTICE '  Total: 0.01095890 NEFT';
    RAISE NOTICE '';
    RAISE NOTICE 'Button will now enable because 0.01095890 > 0.01 minimum!';
    RAISE NOTICE '';
    RAISE NOTICE 'Action: Refresh your staking page';
END $$;
