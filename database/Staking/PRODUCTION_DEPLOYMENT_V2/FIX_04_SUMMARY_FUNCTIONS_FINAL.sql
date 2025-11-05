-- =============================================================================
-- FIX 04: SUMMARY FUNCTIONS (FINAL - MATCHES ACTUAL SCHEMA)
-- =============================================================================
-- Purpose: Update summary functions to match actual schema and return correct field names
-- Deploy: FIFTH (after FIX_01, FIX_01B, FIX_02, FIX_03 final versions)
-- Status: PRODUCTION READY

-- =============================================================================
-- PART 1: GET USER STAKING SUMMARY (MATCHES YOUR SCHEMA)
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_staking_summary(TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nft_count INTEGER;
    token_count INTEGER;
    total_staked_tokens DECIMAL(18,8);
    nft_pending DECIMAL(18,8);
    token_pending DECIMAL(18,8);
    nft_daily_rate_sum DECIMAL(18,8);
    token_daily_rate_sum DECIMAL(18,8);
BEGIN
    -- Count staked NFTs
    SELECT COUNT(*) INTO nft_count
    FROM staked_nfts
    WHERE wallet_address = user_wallet;
    
    -- Count staked token records
    SELECT COUNT(*) INTO token_count
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Sum total staked token amounts
    SELECT COALESCE(SUM(amount), 0) INTO total_staked_tokens
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Calculate total daily reward rates (using daily_reward column)
    SELECT COALESCE(SUM(daily_reward), 0) INTO nft_daily_rate_sum
    FROM staked_nfts
    WHERE wallet_address = user_wallet;
    
    SELECT COALESCE(SUM(daily_reward), 0) INTO token_daily_rate_sum
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Calculate pending rewards using the helper function
    nft_pending := calculate_pending_rewards(user_wallet, 'nft');
    token_pending := calculate_pending_rewards(user_wallet, 'token');
    
    RETURN json_build_object(
        'staked_nfts_count', nft_count,
        'staked_tokens_count', token_count,
        'staked_tokens_amount', total_staked_tokens,
        'daily_nft_rewards', nft_daily_rate_sum,
        'daily_token_rewards', token_daily_rate_sum,
        -- ✅ Frontend expects these field names:
        'nft_pending_rewards', nft_pending,
        'token_pending_rewards', token_pending,
        -- ✅ Also provide old names for backward compatibility:
        'claimable_nft_rewards', nft_pending,
        'claimable_token_rewards', token_pending,
        'total_pending_rewards', nft_pending + token_pending
    );
END;
$$;

-- =============================================================================
-- PART 2: GET USER STAKING SUMMARY BY CHAIN (NEW)
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_staking_summary_by_chain(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary_by_chain(user_wallet TEXT, target_blockchain TEXT DEFAULT 'polygon')
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nft_count INTEGER;
    token_count INTEGER;
    total_staked_tokens DECIMAL(18,8);
    nft_pending DECIMAL(18,8);
    token_pending DECIMAL(18,8);
    nft_daily_rate_sum DECIMAL(18,8);
    token_daily_rate_sum DECIMAL(18,8);
BEGIN
    -- Count staked NFTs for specific blockchain
    SELECT COUNT(*) INTO nft_count
    FROM staked_nfts
    WHERE wallet_address = user_wallet 
    AND blockchain = target_blockchain;
    
    -- Token staking doesn't have blockchain field, count all
    SELECT COUNT(*) INTO token_count
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Sum total staked token amounts
    SELECT COALESCE(SUM(amount), 0) INTO total_staked_tokens
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Calculate daily rates for specific blockchain
    SELECT COALESCE(SUM(daily_reward), 0) INTO nft_daily_rate_sum
    FROM staked_nfts
    WHERE wallet_address = user_wallet
    AND blockchain = target_blockchain;
    
    SELECT COALESCE(SUM(daily_reward), 0) INTO token_daily_rate_sum
    FROM staked_tokens
    WHERE wallet_address = user_wallet;
    
    -- Calculate pending rewards (all chains for tokens, specific chain for NFTs)
    -- Note: This is approximate since staking_rewards doesn't separate by blockchain
    SELECT COALESCE(SUM(nft_earned_today), 0)
    INTO nft_pending
    FROM staking_rewards sr
    WHERE sr.wallet_address = user_wallet 
    AND sr.is_claimed = false
    AND sr.blockchain = target_blockchain;
    
    SELECT COALESCE(SUM(token_earned_today), 0)
    INTO token_pending
    FROM staking_rewards
    WHERE wallet_address = user_wallet 
    AND is_claimed = false;
    
    RETURN json_build_object(
        'blockchain', target_blockchain,
        'staked_nfts_count', nft_count,
        'staked_tokens_count', token_count,
        'staked_tokens_amount', total_staked_tokens,
        'daily_nft_rewards', nft_daily_rate_sum,
        'daily_token_rewards', token_daily_rate_sum,
        'nft_pending_rewards', nft_pending,
        'token_pending_rewards', token_pending,
        'claimable_nft_rewards', nft_pending,
        'claimable_token_rewards', token_pending,
        'total_pending_rewards', nft_pending + token_pending
    );
END;
$$;

-- =============================================================================
-- PART 3: GET USER STAKED NFTs (RETURNS DETAILED LIST)
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_staked_nfts(TEXT);

CREATE OR REPLACE FUNCTION get_user_staked_nfts(user_wallet TEXT)
RETURNS TABLE(
    id UUID,
    nft_id TEXT,
    nft_rarity TEXT,
    staking_source TEXT,
    blockchain TEXT,
    staked_at TIMESTAMP WITH TIME ZONE,
    daily_reward DECIMAL(18,8),
    total_earned DECIMAL(18,8),
    last_claim TIMESTAMP WITH TIME ZONE,
    last_reward_calculated TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    days_staked INTEGER,
    pending_rewards DECIMAL(18,8)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sn.id,
        sn.nft_id,
        sn.nft_rarity,
        sn.staking_source,
        COALESCE(sn.blockchain, 'polygon') as blockchain,
        sn.staked_at,
        sn.daily_reward,
        sn.total_earned,
        sn.last_claim,
        sn.last_reward_calculated,
        sn.transaction_hash,
        EXTRACT(DAY FROM (NOW() - sn.staked_at))::INTEGER as days_staked,
        -- Calculate real-time pending rewards since last claim
        (EXTRACT(EPOCH FROM (NOW() - sn.last_claim)) / 86400.0 * sn.daily_reward)::DECIMAL(18,8) as pending_rewards
    FROM staked_nfts sn
    WHERE sn.wallet_address = user_wallet
    ORDER BY sn.staked_at DESC;
END;
$$;

-- =============================================================================
-- PART 4: GET USER STAKED TOKENS (RETURNS DETAILED LIST)
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_staked_tokens(TEXT);

CREATE OR REPLACE FUNCTION get_user_staked_tokens(user_wallet TEXT)
RETURNS TABLE(
    id UUID,
    amount DECIMAL(18,8),
    apr_rate DECIMAL(5,2),
    daily_reward DECIMAL(18,8),
    staked_at TIMESTAMP WITH TIME ZONE,
    total_earned DECIMAL(18,8),
    last_claim TIMESTAMP WITH TIME ZONE,
    last_reward_calculated TIMESTAMP WITH TIME ZONE,
    days_staked INTEGER,
    pending_rewards DECIMAL(18,8)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.id,
        st.amount,
        st.apr_rate,
        st.daily_reward,
        st.staked_at,
        st.total_earned,
        st.last_claim,
        st.last_reward_calculated,
        EXTRACT(DAY FROM (NOW() - st.staked_at))::INTEGER as days_staked,
        -- Calculate real-time pending rewards since last claim
        (EXTRACT(EPOCH FROM (NOW() - st.last_claim)) / 86400.0 * st.daily_reward)::DECIMAL(18,8) as pending_rewards
    FROM staked_tokens st
    WHERE st.wallet_address = user_wallet
    ORDER BY st.staked_at DESC;
END;
$$;

-- =============================================================================
-- PART 5: GET STAKING REWARDS HISTORY
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_staking_rewards_history(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION get_staking_rewards_history(user_wallet TEXT, days_limit INTEGER DEFAULT 30)
RETURNS TABLE(
    reward_date DATE,
    nft_earned_today DECIMAL(18,8),
    token_earned_today DECIMAL(18,8),
    total_earned DECIMAL(18,8),
    is_claimed BOOLEAN,
    blockchain TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.reward_date,
        sr.nft_earned_today,
        sr.token_earned_today,
        sr.total_earned,
        sr.is_claimed,
        COALESCE(sr.blockchain, 'polygon') as blockchain
    FROM staking_rewards sr
    WHERE sr.wallet_address = user_wallet
    AND sr.reward_date >= CURRENT_DATE - days_limit
    ORDER BY sr.reward_date DESC;
END;
$$;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_user_staking_summary(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_user_staking_summary_by_chain(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_user_staked_nfts(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_user_staked_tokens(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_staking_rewards_history(TEXT, INTEGER) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FIX 04: SUMMARY FUNCTIONS (FINAL - MATCHES YOUR SCHEMA) ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated Functions:';
    RAISE NOTICE '   - get_user_staking_summary(wallet)';
    RAISE NOTICE '   - get_user_staking_summary_by_chain(wallet, chain)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ New Functions:';
    RAISE NOTICE '   - get_user_staked_nfts(wallet)';
    RAISE NOTICE '   - get_user_staked_tokens(wallet)';
    RAISE NOTICE '   - get_staking_rewards_history(wallet, days)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Field Names:';
    RAISE NOTICE '   - nft_pending_rewards ✅ (frontend expects this)';
    RAISE NOTICE '   - token_pending_rewards ✅ (frontend expects this)';
    RAISE NOTICE '   - claimable_nft_rewards ✅ (backward compatibility)';
    RAISE NOTICE '   - claimable_token_rewards ✅ (backward compatibility)';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Schema Compatibility:';
    RAISE NOTICE '   - Uses daily_reward column ✅';
    RAISE NOTICE '   - Uses nft_earned_today, token_earned_today ✅';
    RAISE NOTICE '   - Uses is_claimed boolean ✅';
    RAISE NOTICE '   - Uses apr_rate field ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_05_MIGRATION_FINAL.sql';
    RAISE NOTICE '';
END $$;
