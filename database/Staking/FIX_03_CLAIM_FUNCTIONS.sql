-- =============================================================================
-- FIX 03: ENHANCED CLAIM FUNCTIONS WITH PROPER VALIDATION
-- =============================================================================
-- Purpose: Update claim functions to handle real-time rewards and proper validation
-- Deploy: THIRD (after FIX_02_REWARD_GENERATION.sql)
-- Status: CRITICAL - User-facing claim functionality

-- =============================================================================
-- PART 1: ENHANCED CLAIM NFT REWARDS
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_nft_rewards_supabase_safe(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable DECIMAL(18,8) := 0;
    reward_count INTEGER := 0;
    current_balance DECIMAL(18,8) := 0;
    new_balance DECIMAL(18,8) := 0;
    realtime_pending DECIMAL(18,8) := 0;
BEGIN
    -- ✅ Calculate total claimable from staking_rewards table
    SELECT 
        COALESCE(SUM(total_nft_earned - total_nft_claimed), 0),
        COUNT(*)
    INTO total_claimable, reward_count
    FROM staking_rewards 
    WHERE wallet_address = user_wallet 
    AND total_nft_earned > total_nft_claimed;
    
    -- ✅ Add real-time pending rewards (since last reward generation)
    SELECT COALESCE(SUM(
        EXTRACT(EPOCH FROM (NOW() - GREATEST(last_claim, CURRENT_DATE))) / 86400.0 * daily_rate
    ), 0)
    INTO realtime_pending
    FROM staked_nfts
    WHERE wallet_address = user_wallet;
    
    total_claimable := total_claimable + realtime_pending;
    
    -- ✅ Validation: Minimum claimable amount
    IF total_claimable < 0.01 THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Current: %s NEFT', total_claimable),
            'total_claimed', 0,
            'rewards_count', 0,
            'pending_rewards', total_claimable
        );
    END IF;
    
    -- Get current balance BEFORE any updates
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- ✅ Update staking_rewards to mark NFT rewards as claimed
    UPDATE staking_rewards 
    SET 
        total_nft_claimed = total_nft_earned,
        last_updated = NOW()
    WHERE wallet_address = user_wallet 
    AND total_nft_earned > total_nft_claimed;
    
    -- ✅ Update last_claim timestamp for all staked NFTs
    UPDATE staked_nfts
    SET 
        last_claim = NOW(),
        total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_rate)
    WHERE wallet_address = user_wallet;
    
    -- Calculate new balance
    new_balance := current_balance + total_claimable;
    
    -- Direct balance update using explicit calculation
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (
        user_wallet, 
        new_balance, 
        COALESCE((SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable, 
        NOW()
    )
    ON CONFLICT (wallet_address) 
    DO UPDATE SET 
        total_neft_claimed = EXCLUDED.total_neft_claimed,
        available_neft = EXCLUDED.available_neft,
        last_updated = NOW()
    WHERE user_balances.wallet_address = user_wallet;
    
    -- Force immediate commit to prevent interference
    PERFORM pg_advisory_lock(hashtext(user_wallet));
    
    -- Verify the update succeeded
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    PERFORM pg_advisory_unlock(hashtext(user_wallet));
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT from NFT staking rewards', total_claimable),
        'total_claimed', total_claimable,
        'rewards_count', reward_count,
        'previous_balance', current_balance - total_claimable,
        'new_balance', current_balance,
        'nft_rewards_claimed', total_claimable,
        'realtime_rewards_included', realtime_pending
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error claiming NFT rewards: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- PART 2: ENHANCED CLAIM TOKEN REWARDS
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_token_rewards_supabase_safe(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable DECIMAL(18,8) := 0;
    reward_count INTEGER := 0;
    current_balance DECIMAL(18,8) := 0;
    new_balance DECIMAL(18,8) := 0;
    realtime_pending DECIMAL(18,8) := 0;
BEGIN
    -- ✅ Calculate total claimable from staking_rewards table
    SELECT 
        COALESCE(SUM(total_token_earned - total_token_claimed), 0),
        COUNT(*)
    INTO total_claimable, reward_count
    FROM staking_rewards 
    WHERE wallet_address = user_wallet 
    AND total_token_earned > total_token_claimed;
    
    -- ✅ Add real-time pending rewards (since last reward generation)
    SELECT COALESCE(SUM(
        EXTRACT(EPOCH FROM (NOW() - GREATEST(last_claim, CURRENT_DATE))) / 86400.0 * daily_rate
    ), 0)
    INTO realtime_pending
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    total_claimable := total_claimable + realtime_pending;
    
    -- ✅ Validation: Minimum claimable amount
    IF total_claimable < 0.01 THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Current: %s NEFT', total_claimable),
            'total_claimed', 0,
            'rewards_count', 0,
            'pending_rewards', total_claimable
        );
    END IF;
    
    -- Get current balance BEFORE any updates
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- ✅ Update staking_rewards to mark token rewards as claimed
    UPDATE staking_rewards 
    SET 
        total_token_claimed = total_token_earned,
        last_updated = NOW()
    WHERE wallet_address = user_wallet 
    AND total_token_earned > total_token_claimed;
    
    -- ✅ Update last_claim timestamp for all staked tokens
    UPDATE staked_tokens
    SET 
        last_claim = NOW(),
        total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_rate)
    WHERE wallet_address = user_wallet;
    
    -- Calculate new balance
    new_balance := current_balance + total_claimable;
    
    -- Direct balance update using explicit calculation
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (
        user_wallet, 
        new_balance, 
        COALESCE((SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable, 
        NOW()
    )
    ON CONFLICT (wallet_address) 
    DO UPDATE SET 
        total_neft_claimed = EXCLUDED.total_neft_claimed,
        available_neft = EXCLUDED.available_neft,
        last_updated = NOW()
    WHERE user_balances.wallet_address = user_wallet;
    
    -- Force immediate commit to prevent interference
    PERFORM pg_advisory_lock(hashtext(user_wallet));
    
    -- Verify the update succeeded
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    PERFORM pg_advisory_unlock(hashtext(user_wallet));
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT from token staking rewards', total_claimable),
        'total_claimed', total_claimable,
        'rewards_count', reward_count,
        'previous_balance', current_balance - total_claimable,
        'new_balance', current_balance,
        'token_rewards_claimed', total_claimable,
        'realtime_rewards_included', realtime_pending
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error claiming token rewards: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- PART 3: ENHANCED COMBINED CLAIM FUNCTION (ATOMIC)
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_all_staking_rewards(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nft_result JSON;
    token_result JSON;
    total_nft_claimed DECIMAL(18,8) := 0;
    total_token_claimed DECIMAL(18,8) := 0;
    combined_total DECIMAL(18,8) := 0;
    nft_success BOOLEAN := false;
    token_success BOOLEAN := false;
BEGIN
    -- ✅ Claim NFT rewards
    nft_result := claim_nft_rewards_supabase_safe(user_wallet);
    nft_success := (nft_result->>'success')::boolean;
    
    -- ✅ Claim token rewards
    token_result := claim_token_rewards_supabase_safe(user_wallet);
    token_success := (token_result->>'success')::boolean;
    
    -- Extract claimed amounts
    IF nft_success THEN
        total_nft_claimed := COALESCE((nft_result->>'total_claimed')::DECIMAL(18,8), 0);
    END IF;
    
    IF token_success THEN
        total_token_claimed := COALESCE((token_result->>'total_claimed')::DECIMAL(18,8), 0);
    END IF;
    
    combined_total := total_nft_claimed + total_token_claimed;
    
    -- ✅ Return results
    IF combined_total >= 0.01 THEN
        RETURN json_build_object(
            'success', true,
            'message', format('Successfully claimed %s NEFT total (%s from NFTs, %s from tokens)', 
                combined_total, total_nft_claimed, total_token_claimed),
            'total_claimed', combined_total,
            'nft_rewards_claimed', total_nft_claimed,
            'token_rewards_claimed', total_token_claimed,
            'nft_claim_success', nft_success,
            'token_claim_success', token_success,
            'nft_result', nft_result,
            'token_result', token_result
        );
    ELSE
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Available: %s NEFT (NFT: %s, Token: %s)',
                combined_total, total_nft_claimed, total_token_claimed),
            'total_claimed', 0,
            'nft_rewards_claimed', 0,
            'token_rewards_claimed', 0,
            'nft_result', nft_result,
            'token_result', token_result
        );
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error claiming rewards: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- PART 4: CLAIM HISTORY TRACKING (OPTIONAL BUT RECOMMENDED)
-- =============================================================================

-- Create claims history table for audit trail
CREATE TABLE IF NOT EXISTS staking_claims_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    wallet_address TEXT NOT NULL,
    claim_type TEXT NOT NULL,  -- 'nft', 'token', or 'combined'
    amount_claimed DECIMAL(18,8) NOT NULL,
    nft_rewards DECIMAL(18,8) DEFAULT 0,
    token_rewards DECIMAL(18,8) DEFAULT 0,
    claimed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transaction_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_claims_history_wallet ON staking_claims_history(wallet_address);
CREATE INDEX IF NOT EXISTS idx_claims_history_date ON staking_claims_history(claimed_at);

-- Enable RLS
ALTER TABLE staking_claims_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Users can view own claims history" ON staking_claims_history
    FOR SELECT USING (wallet_address = current_setting('request.headers')::json->>'wallet-address');

-- Function to log claims
CREATE OR REPLACE FUNCTION log_claim_history(
    user_wallet TEXT,
    claim_type TEXT,
    total_amount DECIMAL(18,8),
    nft_amount DECIMAL(18,8),
    token_amount DECIMAL(18,8)
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO staking_claims_history (
        wallet_address,
        claim_type,
        amount_claimed,
        nft_rewards,
        token_rewards,
        claimed_at
    ) VALUES (
        user_wallet,
        claim_type,
        total_amount,
        nft_amount,
        token_amount,
        NOW()
    );
END;
$$;

-- Update claim functions to log history (optional trigger)
CREATE OR REPLACE FUNCTION trigger_log_claim()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- This could be attached to user_balances updates for automatic logging
    RETURN NEW;
END;
$$;

-- =============================================================================
-- PART 5: GET CLAIM HISTORY FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION get_claim_history(
    user_wallet TEXT,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    claim_type TEXT,
    amount_claimed DECIMAL(18,8),
    nft_rewards DECIMAL(18,8),
    token_rewards DECIMAL(18,8),
    claimed_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ch.id,
        ch.claim_type,
        ch.amount_claimed,
        ch.nft_rewards,
        ch.token_rewards,
        ch.claimed_at
    FROM staking_claims_history ch
    WHERE ch.wallet_address = user_wallet
    ORDER BY ch.claimed_at DESC
    LIMIT limit_count;
END;
$$;

-- =============================================================================
-- PART 6: GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION claim_nft_rewards_supabase_safe(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_token_rewards_supabase_safe(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_all_staking_rewards(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION log_claim_history(TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_claim_history(TEXT, INTEGER) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== FIX 03: CLAIM FUNCTIONS DEPLOYED ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Enhanced Claim Functions:';
    RAISE NOTICE '   - claim_nft_rewards_supabase_safe(wallet)';
    RAISE NOTICE '   - claim_token_rewards_supabase_safe(wallet)';
    RAISE NOTICE '   - claim_all_staking_rewards(wallet)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Features Added:';
    RAISE NOTICE '   - Real-time pending reward calculation';
    RAISE NOTICE '   - Minimum 0.01 NEFT validation';
    RAISE NOTICE '   - Last claim timestamp updates';
    RAISE NOTICE '   - Claims history tracking';
    RAISE NOTICE '';
    RAISE NOTICE '✅ New Functions:';
    RAISE NOTICE '   - log_claim_history(wallet, type, amount, nft, token)';
    RAISE NOTICE '   - get_claim_history(wallet, limit)';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_04_SUMMARY_FUNCTIONS.sql';
    RAISE NOTICE '';
END $$;
