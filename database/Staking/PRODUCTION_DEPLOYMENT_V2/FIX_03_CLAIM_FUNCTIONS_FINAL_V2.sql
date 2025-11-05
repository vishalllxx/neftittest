-- =============================================================================
-- FIX 03: CLAIM FUNCTIONS (FINAL V2 - SEPARATE NFT/TOKEN CLAIMS)
-- =============================================================================
-- Purpose: Enhanced claim functions that support SEPARATE NFT and Token claiming
-- Deploy: FOURTH (after FIX_01, FIX_01B, FIX_02_V2)
-- Status: PRODUCTION READY - True separate claiming

-- =============================================================================
-- STRATEGY:
-- Use reward_type field to filter NFT vs Token rewards
-- Each claim function only claims rewards of its specific type
-- =============================================================================

-- =============================================================================
-- PART 1: CLAIM NFT REWARDS ONLY
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_nft_rewards_supabase_safe(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable_nft DECIMAL(18,8);
    current_balance DECIMAL(18,8);
    new_balance DECIMAL(18,8);
    rewards_count INTEGER;
    realtime_nft DECIMAL(18,8);
BEGIN
    -- Calculate total claimable NFT rewards from NFT-specific rows ONLY
    SELECT COALESCE(SUM(reward_amount), 0)
    INTO total_claimable_nft
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND reward_type = 'nft'              -- ✅ Only NFT rewards
    AND is_claimed = false;
    
    -- Add real-time pending NFT rewards since last generation
    realtime_nft := calculate_pending_rewards(user_wallet, 'nft') - total_claimable_nft;
    
    total_claimable_nft := total_claimable_nft + realtime_nft;
    
    -- Check minimum claim amount
    IF total_claimable_nft < 0.01 THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Current NFT rewards: %s NEFT', total_claimable_nft),
            'total_claimed', 0,
            'nft_rewards_claimed', total_claimable_nft,
            'pending_nft_rewards', total_claimable_nft
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- ✅ Mark ONLY NFT rewards as claimed
    UPDATE staking_rewards 
    SET 
        is_claimed = true,
        last_updated = NOW()
    WHERE wallet_address = user_wallet 
    AND reward_type = 'nft'              -- ✅ Only NFT rewards
    AND is_claimed = false;
    
    GET DIAGNOSTICS rewards_count = ROW_COUNT;
    
    -- Update last_claim timestamp for all staked NFTs
    UPDATE staked_nfts
    SET 
        last_claim = NOW(),
        total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_reward)
    WHERE wallet_address = user_wallet;
    
    -- Calculate new balance
    new_balance := current_balance + total_claimable_nft;
    
    -- Update user balance
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (
        user_wallet, 
        new_balance, 
        COALESCE((SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable_nft, 
        NOW()
    )
    ON CONFLICT (wallet_address) 
    DO UPDATE SET 
        total_neft_claimed = EXCLUDED.total_neft_claimed,
        available_neft = EXCLUDED.available_neft,
        last_updated = NOW()
    WHERE user_balances.wallet_address = user_wallet;
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT from NFT staking rewards', total_claimable_nft),
        'total_claimed', total_claimable_nft,
        'nft_rewards_claimed', total_claimable_nft,
        'rewards_days_claimed', rewards_count,
        'previous_balance', current_balance,
        'new_balance', new_balance,
        'note', 'NFT rewards claimed only - token rewards remain pending'
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
-- PART 2: CLAIM TOKEN REWARDS ONLY
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_token_rewards_supabase_safe(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable_token DECIMAL(18,8);
    current_balance DECIMAL(18,8);
    new_balance DECIMAL(18,8);
    rewards_count INTEGER;
    realtime_token DECIMAL(18,8);
BEGIN
    -- Calculate total claimable token rewards from token-specific rows ONLY
    SELECT COALESCE(SUM(reward_amount), 0)
    INTO total_claimable_token
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND reward_type = 'token'            -- ✅ Only Token rewards
    AND is_claimed = false;
    
    -- Add real-time pending token rewards since last generation
    realtime_token := calculate_pending_rewards(user_wallet, 'token') - total_claimable_token;
    
    total_claimable_token := total_claimable_token + realtime_token;
    
    -- Check minimum claim amount
    IF total_claimable_token < 0.01 THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Current Token rewards: %s NEFT', total_claimable_token),
            'total_claimed', 0,
            'token_rewards_claimed', total_claimable_token,
            'pending_token_rewards', total_claimable_token
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- ✅ Mark ONLY Token rewards as claimed
    UPDATE staking_rewards 
    SET 
        is_claimed = true,
        last_updated = NOW()
    WHERE wallet_address = user_wallet 
    AND reward_type = 'token'            -- ✅ Only Token rewards
    AND is_claimed = false;
    
    GET DIAGNOSTICS rewards_count = ROW_COUNT;
    
    -- Update last_claim timestamp for all staked tokens
    UPDATE staked_tokens
    SET 
        last_claim = NOW(),
        total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_reward)
    WHERE wallet_address = user_wallet;
    
    -- Calculate new balance
    new_balance := current_balance + total_claimable_token;
    
    -- Update user balance
    INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
    VALUES (
        user_wallet, 
        new_balance, 
        COALESCE((SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable_token, 
        NOW()
    )
    ON CONFLICT (wallet_address) 
    DO UPDATE SET 
        total_neft_claimed = EXCLUDED.total_neft_claimed,
        available_neft = EXCLUDED.available_neft,
        last_updated = NOW()
    WHERE user_balances.wallet_address = user_wallet;
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT from Token staking rewards', total_claimable_token),
        'total_claimed', total_claimable_token,
        'token_rewards_claimed', total_claimable_token,
        'rewards_days_claimed', rewards_count,
        'previous_balance', current_balance,
        'new_balance', new_balance,
        'note', 'Token rewards claimed only - NFT rewards remain pending'
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
-- PART 3: CLAIM ALL REWARDS (BOTH NFT AND TOKEN)
-- =============================================================================

CREATE OR REPLACE FUNCTION claim_all_staking_rewards(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_claimable_nft DECIMAL(18,8);
    total_claimable_token DECIMAL(18,8);
    total_claimable_all DECIMAL(18,8);
    current_balance DECIMAL(18,8);
    new_balance DECIMAL(18,8);
    nft_rewards_count INTEGER;
    token_rewards_count INTEGER;
    realtime_nft DECIMAL(18,8);
    realtime_token DECIMAL(18,8);
BEGIN
    -- Calculate total claimable NFT rewards
    SELECT COALESCE(SUM(reward_amount), 0)
    INTO total_claimable_nft
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND reward_type = 'nft'
    AND is_claimed = false;
    
    -- Calculate total claimable token rewards
    SELECT COALESCE(SUM(reward_amount), 0)
    INTO total_claimable_token
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND reward_type = 'token'
    AND is_claimed = false;
    
    -- Add real-time pending rewards
    realtime_nft := calculate_pending_rewards(user_wallet, 'nft') - total_claimable_nft;
    realtime_token := calculate_pending_rewards(user_wallet, 'token') - total_claimable_token;
    
    total_claimable_nft := total_claimable_nft + realtime_nft;
    total_claimable_token := total_claimable_token + realtime_token;
    total_claimable_all := total_claimable_nft + total_claimable_token;
    
    -- Check minimum claim amount
    IF total_claimable_all < 0.01 THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Minimum 0.01 NEFT required to claim. Current: %s NEFT', total_claimable_all),
            'total_claimed', 0,
            'nft_rewards', total_claimable_nft,
            'token_rewards', total_claimable_token,
            'pending_rewards', total_claimable_all
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(total_neft_claimed, 0) 
    INTO current_balance
    FROM user_balances 
    WHERE wallet_address = user_wallet;
    
    -- Begin atomic transaction
    BEGIN
        -- Mark ALL unclaimed rewards as claimed (both NFT and Token)
        UPDATE staking_rewards 
        SET 
            is_claimed = true,
            last_updated = NOW()
        WHERE wallet_address = user_wallet 
        AND reward_type = 'nft'
        AND is_claimed = false;
        
        GET DIAGNOSTICS nft_rewards_count = ROW_COUNT;
        
        UPDATE staking_rewards 
        SET 
            is_claimed = true,
            last_updated = NOW()
        WHERE wallet_address = user_wallet 
        AND reward_type = 'token'
        AND is_claimed = false;
        
        GET DIAGNOSTICS token_rewards_count = ROW_COUNT;
        
        -- Update last_claim timestamps
        UPDATE staked_nfts
        SET 
            last_claim = NOW(),
            total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_reward)
        WHERE wallet_address = user_wallet;
        
        UPDATE staked_tokens
        SET 
            last_claim = NOW(),
            total_earned = total_earned + (EXTRACT(EPOCH FROM (NOW() - last_claim)) / 86400.0 * daily_reward)
        WHERE wallet_address = user_wallet;
        
        -- Calculate new balance
        new_balance := current_balance + total_claimable_all;
        
        -- Update user balance
        INSERT INTO user_balances (wallet_address, total_neft_claimed, available_neft, last_updated)
        VALUES (
            user_wallet, 
            new_balance, 
            COALESCE((SELECT available_neft FROM user_balances WHERE wallet_address = user_wallet), 0) + total_claimable_all, 
            NOW()
        )
        ON CONFLICT (wallet_address) 
        DO UPDATE SET 
            total_neft_claimed = EXCLUDED.total_neft_claimed,
            available_neft = EXCLUDED.available_neft,
            last_updated = NOW();
        
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Transaction failed: %', SQLERRM;
    END;
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully claimed %s NEFT total rewards (NFT: %s, Token: %s)', 
            total_claimable_all, total_claimable_nft, total_claimable_token),
        'total_claimed', total_claimable_all,
        'nft_rewards_claimed', total_claimable_nft,
        'token_rewards_claimed', total_claimable_token,
        'nft_days_claimed', nft_rewards_count,
        'token_days_claimed', token_rewards_count,
        'previous_balance', current_balance,
        'new_balance', new_balance
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'message', 'Error claiming all rewards: ' || SQLERRM,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION claim_nft_rewards_supabase_safe(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_token_rewards_supabase_safe(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_all_staking_rewards(TEXT) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FIX 03: CLAIM FUNCTIONS V2 - TRUE SEPARATE CLAIMS ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Enhanced Claim Functions:';
    RAISE NOTICE '   - claim_nft_rewards_supabase_safe(wallet) - NFT ONLY';
    RAISE NOTICE '   - claim_token_rewards_supabase_safe(wallet) - TOKEN ONLY';
    RAISE NOTICE '   - claim_all_staking_rewards(wallet) - BOTH';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Key Features:';
    RAISE NOTICE '   - TRUE separate claiming using reward_type field';
    RAISE NOTICE '   - Claim NFT rewards independently from tokens ✅';
    RAISE NOTICE '   - Claim token rewards independently from NFTs ✅';
    RAISE NOTICE '   - Real-time pending reward calculation';
    RAISE NOTICE '   - Minimum 0.01 NEFT validation';
    RAISE NOTICE '   - Atomic transactions';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 How It Works:';
    RAISE NOTICE '   - NFT claim: WHERE reward_type = ''nft''';
    RAISE NOTICE '   - Token claim: WHERE reward_type = ''token''';
    RAISE NOTICE '   - Each type tracked in separate rows';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_04_SUMMARY_FUNCTIONS_FINAL_V2.sql';
    RAISE NOTICE '';
END $$;
