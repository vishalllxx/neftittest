-- ============================================================================
-- GENERATE STAKING REWARDS WITH BLOCKCHAIN TRACKING
-- ============================================================================
-- This generates pending rewards for all staked NFTs/tokens
-- Updated to include blockchain tracking for chain-specific rewards
-- ============================================================================

-- First, let's manually generate rewards for your current stakes
DO $$
DECLARE
    wallet_record RECORD;
    nft_daily_total DECIMAL(18,8);
    token_daily_total DECIMAL(18,8);
    nft_blockchain TEXT;
    processed_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Generating staking rewards with blockchain tracking...';
    RAISE NOTICE 'Reward Date: %', CURRENT_DATE;
    
    -- Process each wallet with staked NFTs
    FOR wallet_record IN (
        SELECT DISTINCT wallet_address 
        FROM staked_nfts
        WHERE staked_at <= NOW() - INTERVAL '1 hour' -- At least 1 hour staked
    ) LOOP
        -- Calculate daily NFT rewards and get blockchain
        SELECT 
            COALESCE(SUM(daily_reward), 0),
            COALESCE(MAX(blockchain), 'polygon-amoy') -- Use first NFT's blockchain
        INTO nft_daily_total, nft_blockchain
        FROM staked_nfts 
        WHERE wallet_address = wallet_record.wallet_address
        AND staked_at <= NOW() - INTERVAL '1 hour';
        
        -- Calculate daily token rewards (chain-agnostic)
        SELECT COALESCE(SUM(daily_reward), 0)
        INTO token_daily_total
        FROM staked_tokens 
        WHERE wallet_address = wallet_record.wallet_address
        AND staked_at <= NOW() - INTERVAL '1 hour';
        
        -- Only create reward if there's something to reward
        IF nft_daily_total > 0 OR token_daily_total > 0 THEN
            -- Insert reward record with blockchain tracking
            BEGIN
                -- Try with 'claimed' column first
                INSERT INTO staking_rewards (
                    wallet_address,
                    reward_date,
                    nft_rewards,
                    token_rewards,
                    total_rewards,
                    blockchain,  -- Track which blockchain
                    claimed,
                    created_at
                ) VALUES (
                    wallet_record.wallet_address,
                    CURRENT_DATE,
                    nft_daily_total,
                    token_daily_total,
                    nft_daily_total + token_daily_total,
                    nft_blockchain,  -- Blockchain from staked NFTs
                    FALSE,
                    NOW()
                )
                ON CONFLICT (wallet_address, reward_date) 
                DO UPDATE SET
                    nft_rewards = EXCLUDED.nft_rewards,
                    token_rewards = EXCLUDED.token_rewards,
                    total_rewards = EXCLUDED.total_rewards,
                    blockchain = EXCLUDED.blockchain;
                    
                processed_count := processed_count + 1;
                
                RAISE NOTICE '✅ Generated rewards for %: NFT=% (%), Token=%', 
                    wallet_record.wallet_address, 
                    nft_daily_total,
                    nft_blockchain,
                    token_daily_total;
                    
            EXCEPTION WHEN undefined_column THEN
                -- Fall back to 'is_claimed' column
                INSERT INTO staking_rewards (
                    wallet_address,
                    reward_date,
                    nft_rewards,
                    token_rewards,
                    total_rewards,
                    blockchain,
                    is_claimed,
                    created_at
                ) VALUES (
                    wallet_record.wallet_address,
                    CURRENT_DATE,
                    nft_daily_total,
                    token_daily_total,
                    nft_daily_total + token_daily_total,
                    nft_blockchain,
                    FALSE,
                    NOW()
                )
                ON CONFLICT (wallet_address, reward_date) 
                DO UPDATE SET
                    nft_rewards = EXCLUDED.nft_rewards,
                    token_rewards = EXCLUDED.token_rewards,
                    total_rewards = EXCLUDED.total_rewards,
                    blockchain = EXCLUDED.blockchain;
                    
                processed_count := processed_count + 1;
            END;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ REWARD GENERATION COMPLETE';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ Processed % wallets', processed_count;
    RAISE NOTICE '✅ Rewards generated for: %', CURRENT_DATE;
    RAISE NOTICE '✅ Blockchain tracking: ENABLED';
    RAISE NOTICE '';
END $$;

-- Verify rewards were created
SELECT 
    'Generated Rewards' as check_type,
    wallet_address,
    reward_date,
    blockchain,
    nft_rewards,
    token_rewards,
    total_rewards,
    COALESCE(claimed, is_claimed) as is_claimed
FROM staking_rewards
WHERE reward_date = CURRENT_DATE
ORDER BY total_rewards DESC;

-- Show summary by blockchain
SELECT 
    'Rewards by Blockchain' as summary_type,
    blockchain,
    COUNT(*) as wallets,
    SUM(nft_rewards) as total_nft_rewards,
    SUM(token_rewards) as total_token_rewards,
    SUM(total_rewards) as total_all_rewards
FROM staking_rewards
WHERE reward_date = CURRENT_DATE
GROUP BY blockchain;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 ============================================================================';
    RAISE NOTICE '📊 NEXT STEPS';
    RAISE NOTICE '📊 ============================================================================';
    RAISE NOTICE '1. Refresh your staking page in the browser';
    RAISE NOTICE '2. Pending rewards should now show correctly';
    RAISE NOTICE '3. Rewards are filtered by blockchain (polygon-amoy, sepolia, etc.)';
    RAISE NOTICE '4. Check the query results above to verify your rewards';
    RAISE NOTICE '';
END $$;
