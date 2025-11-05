-- ============================================================================
-- FIX CHAIN-SPECIFIC STAKING REWARDS
-- ============================================================================
-- Problem: Pending rewards show the SAME value across different blockchains
-- Root Cause: get_user_staking_summary() doesn't filter by blockchain
-- Solution: Add blockchain tracking and chain-specific filtering
-- ============================================================================

-- Step 1: Add blockchain column to staking tables if not exists
-- ============================================================================

-- Add blockchain column to staked_nfts table
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'staked_nfts' AND column_name = 'blockchain'
    ) THEN
        ALTER TABLE staked_nfts 
        ADD COLUMN blockchain TEXT DEFAULT 'polygon-amoy';
        
        RAISE NOTICE '✅ Added blockchain column to staked_nfts table';
    ELSE
        RAISE NOTICE 'ℹ️  blockchain column already exists in staked_nfts';
    END IF;
END $$;

-- Skip adding blockchain to staked_tokens - tokens are chain-agnostic
DO $$ 
BEGIN
    RAISE NOTICE 'ℹ️  Skipping blockchain column for staked_tokens - tokens are fungible and chain-agnostic';
    RAISE NOTICE 'ℹ️  Only NFTs need blockchain tracking since they are unique to specific chains';
END $$;

-- Add blockchain column to staking_rewards table
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'staking_rewards' AND column_name = 'blockchain'
    ) THEN
        ALTER TABLE staking_rewards 
        ADD COLUMN blockchain TEXT DEFAULT 'polygon-amoy';
        
        RAISE NOTICE '✅ Added blockchain column to staking_rewards table';
    ELSE
        RAISE NOTICE 'ℹ️  blockchain column already exists in staking_rewards';
    END IF;
END $$;

-- Step 2: Create chain-specific staking summary function
-- ============================================================================

DROP FUNCTION IF EXISTS get_user_staking_summary_by_chain(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary_by_chain(
    user_wallet TEXT,
    chain_filter TEXT DEFAULT NULL  -- NULL = all chains, otherwise specific chain
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    total_unclaimed DECIMAL(18,8) := 0;
    nft_unclaimed DECIMAL(18,8) := 0;
    token_unclaimed DECIMAL(18,8) := 0;
    staked_nfts INT := 0;
    staked_tokens_amt DECIMAL(18,8) := 0;
    daily_nft_rew DECIMAL(18,8) := 0;
    daily_token_rew DECIMAL(18,8) := 0;
BEGIN
    -- If chain_filter is provided, filter by blockchain
    -- Otherwise, aggregate across all chains
    
    -- Get staked NFTs count (chain-specific if filter provided)
    IF chain_filter IS NOT NULL THEN
        SELECT COUNT(*) INTO staked_nfts
        FROM staked_nfts 
        WHERE wallet_address = user_wallet 
        AND (blockchain = chain_filter OR blockchain IS NULL);  -- Handle legacy data without blockchain
    ELSE
        SELECT COUNT(*) INTO staked_nfts
        FROM staked_nfts 
        WHERE wallet_address = user_wallet;
    END IF;
    
    -- Get staked tokens amount (NOT chain-specific - tokens are fungible)
    SELECT COALESCE(SUM(amount), 0) INTO staked_tokens_amt
    FROM staked_tokens 
    WHERE wallet_address = user_wallet;
    
    -- Get daily NFT rewards (chain-specific if filter provided)
    IF chain_filter IS NOT NULL THEN
        SELECT COALESCE(SUM(daily_reward), 0) INTO daily_nft_rew
        FROM staked_nfts 
        WHERE wallet_address = user_wallet 
        AND (blockchain = chain_filter OR blockchain IS NULL);
    ELSE
        SELECT COALESCE(SUM(daily_reward), 0) INTO daily_nft_rew
        FROM staked_nfts 
        WHERE wallet_address = user_wallet;
    END IF;
    
    -- Get daily token rewards (NOT chain-specific - tokens are fungible)
    SELECT COALESCE(SUM(daily_reward), 0) INTO daily_token_rew
    FROM staked_tokens 
    WHERE wallet_address = user_wallet;
    
    -- Get unclaimed rewards breakdown (chain-specific if filter provided)
    -- Use correct column names: total_earned, nft_earned_today, token_earned_today
    IF chain_filter IS NOT NULL THEN
        SELECT 
            COALESCE(SUM(total_earned), 0),
            COALESCE(SUM(nft_earned_today), 0),
            COALESCE(SUM(token_earned_today), 0)
        INTO total_unclaimed, nft_unclaimed, token_unclaimed
        FROM staking_rewards 
        WHERE wallet_address = user_wallet 
        AND is_claimed = FALSE
        AND (blockchain = chain_filter OR blockchain IS NULL);
    ELSE
        SELECT 
            COALESCE(SUM(total_earned), 0),
            COALESCE(SUM(nft_earned_today), 0),
            COALESCE(SUM(token_earned_today), 0)
        INTO total_unclaimed, nft_unclaimed, token_unclaimed
        FROM staking_rewards 
        WHERE wallet_address = user_wallet 
        AND is_claimed = FALSE;
    END IF;
    
    -- Build result JSON
    SELECT json_build_object(
        'staked_nfts_count', staked_nfts,
        'staked_tokens_amount', staked_tokens_amt,
        'daily_nft_rewards', daily_nft_rew,
        'daily_token_rewards', daily_token_rew,
        'total_pending_rewards', total_unclaimed,
        'nft_pending_rewards', nft_unclaimed,
        'token_pending_rewards', token_unclaimed,
        'blockchain_filter', chain_filter,
        'is_chain_specific', chain_filter IS NOT NULL
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_staking_summary_by_chain(TEXT, TEXT) TO authenticated, anon, public;

-- Step 3: Update the original function to maintain backward compatibility
-- ============================================================================

DROP FUNCTION IF EXISTS get_user_staking_summary(TEXT);

CREATE OR REPLACE FUNCTION get_user_staking_summary(user_wallet TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Call the new chain-specific function with NULL filter (all chains)
    -- This maintains backward compatibility
    RETURN get_user_staking_summary_by_chain(user_wallet, NULL);
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_staking_summary(TEXT) TO authenticated, anon, public;

-- Step 4: Create helper function to get current user's chain-specific summary
-- ============================================================================

CREATE OR REPLACE FUNCTION get_my_staking_summary_for_chain(chain_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_wallet TEXT;
BEGIN
    -- Get current user's wallet from request headers
    user_wallet := current_setting('request.headers')::json->>'x-wallet-address';
    
    IF user_wallet IS NULL THEN
        RAISE EXCEPTION 'No wallet address provided in request headers';
    END IF;
    
    RETURN get_user_staking_summary_by_chain(user_wallet, chain_name);
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_staking_summary_for_chain(TEXT) TO authenticated, anon, public;

-- Step 5: Create indexes for performance
-- ============================================================================

-- Index on blockchain column for staked_nfts
CREATE INDEX IF NOT EXISTS idx_staked_nfts_blockchain 
ON staked_nfts(wallet_address, blockchain);

-- Skip index for staked_tokens - no blockchain column needed
-- Tokens are fungible and not tied to specific chains

-- Index on blockchain column for staking_rewards
-- Create index conditionally based on which claimed column exists
DO $$
BEGIN
    -- Try creating index with 'claimed' column first
    BEGIN
        CREATE INDEX IF NOT EXISTS idx_staking_rewards_blockchain 
        ON staking_rewards(wallet_address, blockchain, claimed);
        RAISE NOTICE '✅ Created index with claimed column';
    EXCEPTION WHEN undefined_column THEN
        -- Fall back to 'is_claimed' column
        CREATE INDEX IF NOT EXISTS idx_staking_rewards_blockchain 
        ON staking_rewards(wallet_address, blockchain, is_claimed);
        RAISE NOTICE '✅ Created index with is_claimed column';
    END;
END $$;

-- Step 6: Update existing stake_nft_with_source to include blockchain
-- ============================================================================

CREATE OR REPLACE FUNCTION stake_nft_with_source(
    user_wallet TEXT,
    p_nft_id TEXT,
    nft_name TEXT,
    nft_rarity TEXT,
    nft_image TEXT,
    nft_description TEXT DEFAULT '',
    nft_attributes JSONB DEFAULT '[]'::jsonb,
    staking_source TEXT DEFAULT 'offchain',
    transaction_hash TEXT DEFAULT NULL,
    nft_blockchain TEXT DEFAULT 'polygon'  -- NEW: Default to polygon for backward compatibility
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    daily_reward_amount DECIMAL(18,8);
    result JSON;
BEGIN
    -- Check if NFT is already staked
    IF EXISTS (
        SELECT 1 FROM staked_nfts 
        WHERE wallet_address = user_wallet 
        AND nft_id = p_nft_id
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'NFT is already staked'
        );
    END IF;

    -- Calculate daily reward based on rarity
    daily_reward_amount := CASE LOWER(nft_rarity)
        WHEN 'common' THEN 0.1
        WHEN 'rare' THEN 0.4
        WHEN 'legendary' THEN 1.0
        WHEN 'platinum' THEN 2.5
        WHEN 'silver' THEN 8.0
        WHEN 'gold' THEN 30.0
        ELSE 0.1
    END;

    -- Insert into staked_nfts with blockchain tracking
    INSERT INTO staked_nfts (
        wallet_address,
        nft_id,
        name,
        rarity,
        image,
        description,
        attributes,
        daily_reward,
        staked_at,
        staking_source,
        transaction_hash,
        blockchain  -- NEW COLUMN
    ) VALUES (
        user_wallet,
        p_nft_id,
        nft_name,
        nft_rarity,
        nft_image,
        nft_description,
        nft_attributes,
        daily_reward_amount,
        NOW(),
        staking_source,
        transaction_hash,
        nft_blockchain  -- Store the blockchain
    );

    result := json_build_object(
        'success', true,
        'message', 'NFT staked successfully',
        'data', json_build_object(
            'nft_id', p_nft_id,
            'daily_reward', daily_reward_amount,
            'staking_source', staking_source,
            'blockchain', nft_blockchain
        )
    );

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION stake_nft_with_source(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, TEXT) TO authenticated, anon, public;

-- ============================================================================
-- DEPLOYMENT SUMMARY
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ CHAIN-SPECIFIC STAKING REWARDS FIX DEPLOYED';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Changes Applied:';
    RAISE NOTICE '   1. ✅ Added blockchain column to staked_nfts and staking_rewards';
    RAISE NOTICE '   2. ⏭️  SKIPPED blockchain for staked_tokens (tokens are chain-agnostic)';
    RAISE NOTICE '   3. ✅ Created get_user_staking_summary_by_chain(wallet, chain) function';
    RAISE NOTICE '   4. ✅ Updated get_user_staking_summary(wallet) for backward compatibility';
    RAISE NOTICE '   5. ✅ Created get_my_staking_summary_for_chain(chain) helper';
    RAISE NOTICE '   6. ✅ Added performance indexes on blockchain columns';
    RAISE NOTICE '   7. ✅ Updated stake_nft_with_source to track blockchain';
    RAISE NOTICE '';
    RAISE NOTICE '💡 Important Notes:';
    RAISE NOTICE '   • NFT staking: CHAIN-SPECIFIC (tracked by blockchain column)';
    RAISE NOTICE '   • Token staking: CHAIN-AGNOSTIC (no blockchain tracking needed)';
    RAISE NOTICE '   • Staking rewards: CHAIN-SPECIFIC (filtered by blockchain)';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Usage Examples:';
    RAISE NOTICE '   • All chains: SELECT get_user_staking_summary(''0x123...'')';
    RAISE NOTICE '   • Polygon only: SELECT get_user_staking_summary_by_chain(''0x123...'', ''polygon-amoy'')';
    RAISE NOTICE '   • Ethereum only: SELECT get_user_staking_summary_by_chain(''0x123...'', ''sepolia'')';
    RAISE NOTICE '   • BNB only: SELECT get_user_staking_summary_by_chain(''0x123...'', ''bsc-testnet'')';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  MIGRATION NOTE:';
    RAISE NOTICE '   Existing staked NFTs will have blockchain=NULL or ''polygon'' (default)';
    RAISE NOTICE '   New NFT stakes will track blockchain correctly';
    RAISE NOTICE '   Token stakes remain chain-agnostic (as they should be)';
    RAISE NOTICE '';
END $$;
