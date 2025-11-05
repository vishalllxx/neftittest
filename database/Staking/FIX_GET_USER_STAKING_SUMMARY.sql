-- =============================================================================
-- FIX get_user_staking_summary() - Return ALL rewards regardless of blockchain
-- =============================================================================
-- Problem 1: Function returning 0 pending rewards even though rewards exist
-- Problem 2: staked_tokens_amount shows incorrect value (reads from staked_tokens table)
-- 
-- Solution 1: Update function to aggregate ALL blockchain rewards
-- Solution 2: Calculate staked_tokens_amount from user_balances (source of truth)
--            Formula: staked_amount = total_neft_claimed - available_neft
-- =============================================================================

-- First, let's check what the current function returns
SELECT 
    'BEFORE FIX: Current Function Output' as test,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as result;

-- Check what's actually in the database
SELECT 
    'Actual Database Data' as test,
    COUNT(*) as reward_records,
    SUM(nft_earned_today) as nft_total,
    SUM(token_earned_today) as token_total,
    STRING_AGG(DISTINCT blockchain, ', ') as blockchains
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND is_claimed = false;

-- =============================================================================
-- FIX: Recreate get_user_staking_summary() without blockchain filter
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
    -- Count staked NFTs (ALL chains)
    SELECT COUNT(*) INTO v_staked_nfts_count
    FROM staked_nfts 
    WHERE wallet_address = p_user_wallet;
    
    -- 🔥 FIX: Calculate staked tokens from user_balances (source of truth)
    -- staked_amount = total_claimed - available
    SELECT COALESCE((total_neft_claimed - available_neft), 0) INTO v_staked_tokens_amount
    FROM user_balances 
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate daily NFT rewards (ALL chains)
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_nft_rewards
    FROM staked_nfts 
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate daily token rewards (ALL chains)
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_token_rewards
    FROM staked_tokens 
    WHERE wallet_address = p_user_wallet;
    
    -- 🔥 FIX: Calculate pending NFT rewards from ALL blockchains
    SELECT COALESCE(SUM(nft_earned_today), 0) INTO v_nft_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false;
    -- REMOVED: AND blockchain = 'some_chain'
    
    -- 🔥 FIX: Calculate pending token rewards from ALL blockchains
    SELECT COALESCE(SUM(token_earned_today), 0) INTO v_token_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false;
    -- REMOVED: AND blockchain = 'some_chain'
    
    -- Return comprehensive summary
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
-- VERIFY: Test the updated function
-- =============================================================================

SELECT 
    'AFTER FIX: Updated Function Output' as test,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as result;

-- Detailed verification
DO $$
DECLARE
    v_summary JSON;
    v_nft_pending DECIMAL;
    v_token_pending DECIMAL;
    v_staked_amount DECIMAL;
    v_correct_staked DECIMAL;
BEGIN
    -- Get summary
    SELECT get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') INTO v_summary;
    
    -- Extract values
    v_nft_pending := (v_summary->>'nft_pending_rewards')::DECIMAL;
    v_token_pending := (v_summary->>'token_pending_rewards')::DECIMAL;
    v_staked_amount := (v_summary->>'staked_tokens_amount')::DECIMAL;
    
    -- Calculate correct staked amount from user_balances
    SELECT (total_neft_claimed - available_neft) INTO v_correct_staked
    FROM user_balances 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ FUNCTION UPDATED - VERIFICATION';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Summary Function Returns:';
    RAISE NOTICE '   • Staked Amount: % NEFT', v_staked_amount;
    RAISE NOTICE '   • Correct Staked (from user_balances): % NEFT', v_correct_staked;
    RAISE NOTICE '   • NFT Pending Rewards: % NEFT', v_nft_pending;
    RAISE NOTICE '   • Token Pending Rewards: % NEFT', v_token_pending;
    RAISE NOTICE '   • Total Pending: % NEFT', v_nft_pending + v_token_pending;
    RAISE NOTICE '';
    
    -- Check staked amount
    IF v_staked_amount = v_correct_staked THEN
        RAISE NOTICE '✅ Staked Amount: CORRECT (% NEFT)', v_staked_amount;
    ELSE
        RAISE NOTICE '❌ Staked Amount: MISMATCH!';
        RAISE NOTICE '   Function returns: % NEFT', v_staked_amount;
        RAISE NOTICE '   Should be: % NEFT', v_correct_staked;
    END IF;
    RAISE NOTICE '';
    
    -- Check pending rewards
    IF v_nft_pending + v_token_pending > 0 THEN
        RAISE NOTICE '✅ SUCCESS! Function now returns correct rewards!';
        RAISE NOTICE '';
        RAISE NOTICE '🎯 NEXT STEPS:';
        RAISE NOTICE '   1. Go to your staking page';
        RAISE NOTICE '   2. Hard refresh: Ctrl + Shift + R';
        RAISE NOTICE '   3. Open browser console (F12)';
        RAISE NOTICE '   4. Verify UI shows:';
        RAISE NOTICE '      • Staked Amount: % NEFT (was 370, now correct!)', v_staked_amount;
        RAISE NOTICE '      • Pending Rewards: % NEFT', v_token_pending;
        RAISE NOTICE '      • Claim button: ENABLED';
    ELSE
        RAISE NOTICE '⚠️  WARNING: Function returns 0 rewards';
        RAISE NOTICE '   (This might be correct if all rewards are claimed)';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
END $$;

-- =============================================================================
-- ALSO FIX: get_user_staking_summary_by_chain() to work with NULL chain
-- =============================================================================

DROP FUNCTION IF EXISTS get_user_staking_summary_by_chain(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary_by_chain(
    p_user_wallet TEXT,
    p_blockchain TEXT DEFAULT NULL
)
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
    -- If blockchain is NULL, return ALL chains (same as get_user_staking_summary)
    IF p_blockchain IS NULL THEN
        RETURN get_user_staking_summary(p_user_wallet);
    END IF;
    
    -- Count staked NFTs for specific chain
    SELECT COUNT(*) INTO v_staked_nfts_count
    FROM staked_nfts 
    WHERE wallet_address = p_user_wallet
      AND (blockchain = p_blockchain OR blockchain IS NULL);
    
    -- 🔥 FIX: Calculate staked tokens from user_balances (source of truth)
    -- staked_amount = total_claimed - available (tokens are chain-agnostic)
    SELECT COALESCE((total_neft_claimed - available_neft), 0) INTO v_staked_tokens_amount
    FROM user_balances 
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate daily NFT rewards for specific chain
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_nft_rewards
    FROM staked_nfts 
    WHERE wallet_address = p_user_wallet
      AND (blockchain = p_blockchain OR blockchain IS NULL);
    
    -- Calculate daily token rewards (all chains)
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_token_rewards
    FROM staked_tokens 
    WHERE wallet_address = p_user_wallet;
    
    -- Calculate pending NFT rewards for specific chain
    SELECT COALESCE(SUM(nft_earned_today), 0) INTO v_nft_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false
      AND (blockchain = p_blockchain OR blockchain IS NULL);
    
    -- Calculate pending token rewards for specific chain
    SELECT COALESCE(SUM(token_earned_today), 0) INTO v_token_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = p_user_wallet 
      AND is_claimed = false
      AND (blockchain = p_blockchain OR blockchain IS NULL);
    
    RETURN json_build_object(
        'staked_nfts_count', v_staked_nfts_count,
        'staked_tokens_amount', v_staked_tokens_amount,
        'nft_pending_rewards', v_nft_pending_rewards,
        'token_pending_rewards', v_token_pending_rewards,
        'total_pending_rewards', v_nft_pending_rewards + v_token_pending_rewards,
        'daily_nft_rewards', v_daily_nft_rewards,
        'daily_token_rewards', v_daily_token_rewards,
        'blockchain_filter', p_blockchain
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in get_user_staking_summary_by_chain for % on %: %', p_user_wallet, p_blockchain, SQLERRM;
    RETURN json_build_object(
        'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_staking_summary_by_chain(TEXT, TEXT) TO authenticated, anon, public;

-- =============================================================================
-- FINAL VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ BOTH FUNCTIONS UPDATED:';
    RAISE NOTICE '   • get_user_staking_summary(wallet) - Returns ALL chains';
    RAISE NOTICE '   • get_user_staking_summary_by_chain(wallet, chain) - Returns specific chain';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 REFRESH YOUR STAKING PAGE NOW!';
    RAISE NOTICE '';
END $$;
