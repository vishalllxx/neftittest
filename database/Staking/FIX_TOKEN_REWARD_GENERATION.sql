-- ============================================================================
-- FIX TOKEN REWARD GENERATION - Include tokens in daily cron job
-- ============================================================================

-- First, clean up duplicate records and create unique constraint
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    -- Check for duplicates
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT wallet_address, reward_date, COUNT(*) as cnt
        FROM staking_rewards
        GROUP BY wallet_address, reward_date
        HAVING COUNT(*) > 1
    ) duplicates;
    
    RAISE NOTICE 'Found % duplicate wallet/date combinations', duplicate_count;
    
    -- Clean up duplicates if they exist
    IF duplicate_count > 0 THEN
        RAISE NOTICE '🔄 Cleaning up duplicate records...';
        
        -- Keep only the latest record for each wallet/date combination
        DELETE FROM staking_rewards
        WHERE id NOT IN (
            SELECT DISTINCT ON (wallet_address, reward_date) id
            FROM staking_rewards
            ORDER BY wallet_address, reward_date, created_at DESC
        );
        
        RAISE NOTICE '✅ Cleaned up duplicate records';
    END IF;
    
    -- Add unique constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'staking_rewards_wallet_date_unique'
    ) THEN
        ALTER TABLE staking_rewards 
        ADD CONSTRAINT staking_rewards_wallet_date_unique 
        UNIQUE (wallet_address, reward_date);
        
        RAISE NOTICE '✅ Added unique constraint on (wallet_address, reward_date)';
    ELSE
        RAISE NOTICE 'ℹ️  Unique constraint already exists';
    END IF;
END $$;

-- Update the generate_daily_staking_rewards function to include both NFT and token rewards
CREATE OR REPLACE FUNCTION generate_daily_staking_rewards()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    wallet_record RECORD;
    nft_daily_total DECIMAL(18,8);
    token_daily_total DECIMAL(18,8);
    nft_blockchain TEXT;
    processed_count INTEGER := 0;
    current_reward_date DATE := CURRENT_DATE;
BEGIN
    RAISE NOTICE '🔄 Generating daily staking rewards for date: %', current_reward_date;
    
    -- Process each wallet that has staked NFTs OR tokens (24+ hours ago)
    FOR wallet_record IN (
        SELECT DISTINCT wallet_address 
        FROM (
            SELECT wallet_address FROM staked_nfts 
            WHERE staked_at <= NOW() - INTERVAL '24 hours'
            UNION
            SELECT wallet_address FROM staked_tokens 
            WHERE staked_at <= NOW() - INTERVAL '24 hours'
        ) AS all_stakers
    ) LOOP
        -- Calculate daily NFT rewards and get blockchain (only for NFTs staked 24+ hours)
        SELECT 
            COALESCE(SUM(daily_reward), 0),
            COALESCE(MAX(blockchain), 'polygon-amoy')
        INTO nft_daily_total, nft_blockchain
        FROM staked_nfts 
        WHERE wallet_address = wallet_record.wallet_address
        AND staked_at <= NOW() - INTERVAL '24 hours';
        
        -- Calculate daily token rewards (only for tokens staked 24+ hours)
        SELECT COALESCE(SUM(daily_reward), 0)
        INTO token_daily_total
        FROM staked_tokens 
        WHERE wallet_address = wallet_record.wallet_address
        AND staked_at <= NOW() - INTERVAL '24 hours';
        
        -- Only create reward if there's something to reward
        IF nft_daily_total > 0 OR token_daily_total > 0 THEN
            -- Insert reward record with both NFT and token rewards
            INSERT INTO staking_rewards (
                wallet_address,
                reward_date,
                nft_earned_today,
                token_earned_today,
                total_earned,
                blockchain,
                is_claimed,
                created_at
            ) VALUES (
                wallet_record.wallet_address,
                current_reward_date,
                nft_daily_total,
                token_daily_total,
                nft_daily_total + token_daily_total,
                nft_blockchain,
                FALSE,
                NOW()
            )
            ON CONFLICT (wallet_address, reward_date) 
            DO UPDATE SET
                nft_earned_today = EXCLUDED.nft_earned_today,
                token_earned_today = EXCLUDED.token_earned_today,
                total_earned = EXCLUDED.total_earned,
                blockchain = EXCLUDED.blockchain,
                last_updated = NOW();
            
            -- Update last_reward_calculated for staked tokens (24+ hours old)
            UPDATE staked_tokens
            SET last_reward_calculated = NOW()
            WHERE wallet_address = wallet_record.wallet_address
            AND staked_at <= NOW() - INTERVAL '24 hours';
                
            processed_count := processed_count + 1;
            
            RAISE NOTICE '✅ Generated rewards for %: NFT=% NEFT (%), Token=% NEFT', 
                wallet_record.wallet_address, 
                nft_daily_total,
                nft_blockchain,
                token_daily_total;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Reward generation complete: % wallets processed', processed_count;
    RETURN processed_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO authenticated, anon, public, service_role;

-- Generate missing token rewards for the past 10 days
DO $$
DECLARE
    missing_date DATE;
    wallet_record RECORD;
    token_daily_total DECIMAL(18,8);
    days_processed INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Generating missing token rewards for past 10 days...';
    
    -- Generate rewards for each missing day
    FOR missing_date IN 
        SELECT generate_series(CURRENT_DATE - INTERVAL '10 days', CURRENT_DATE - INTERVAL '1 day', '1 day')::DATE
    LOOP
        -- Process each wallet with staked tokens (staked 24+ hours before the missing date)
        FOR wallet_record IN (
            SELECT DISTINCT wallet_address 
            FROM staked_tokens
            WHERE staked_at <= missing_date - INTERVAL '24 hours'
        ) LOOP
            -- Calculate token rewards for this date (only for tokens staked 24+ hours)
            SELECT COALESCE(SUM(daily_reward), 0)
            INTO token_daily_total
            FROM staked_tokens 
            WHERE wallet_address = wallet_record.wallet_address
            AND staked_at <= missing_date - INTERVAL '24 hours';
            
            -- Only add token rewards if they don't exist and amount > 0
            IF token_daily_total > 0 THEN
                INSERT INTO staking_rewards (
                    wallet_address,
                    reward_date,
                    nft_earned_today,
                    token_earned_today,
                    total_earned,
                    blockchain,
                    is_claimed,
                    created_at
                ) VALUES (
                    wallet_record.wallet_address,
                    missing_date,
                    0, -- No NFT rewards for backfill
                    token_daily_total,
                    token_daily_total,
                    'polygon-amoy',
                    FALSE,
                    NOW()
                )
                ON CONFLICT (wallet_address, reward_date) 
                DO UPDATE SET
                    token_earned_today = GREATEST(staking_rewards.token_earned_today, EXCLUDED.token_earned_today),
                    total_earned = staking_rewards.nft_earned_today + GREATEST(staking_rewards.token_earned_today, EXCLUDED.token_earned_today),
                    last_updated = NOW()
                WHERE staking_rewards.token_earned_today < EXCLUDED.token_earned_today;
            END IF;
        END LOOP;
        
        days_processed := days_processed + 1;
    END LOOP;
    
    RAISE NOTICE '✅ Backfilled token rewards for % days', days_processed;
END $$;

-- Test the updated function
SELECT 
    'Updated Function Test' as test_type,
    generate_daily_staking_rewards() as wallets_processed,
    NOW() as test_time;

-- Check your updated rewards
SELECT 
    reward_date,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed
FROM staking_rewards
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
AND reward_date >= CURRENT_DATE - INTERVAL '3 days'
ORDER BY reward_date DESC;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '✅ TOKEN REWARD GENERATION FIXED';
    RAISE NOTICE '✅ ============================================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Fixed Issues:';
    RAISE NOTICE '   1. ✅ Updated generate_daily_staking_rewards() to include token rewards';
    RAISE NOTICE '   2. ✅ Backfilled missing token rewards for past 10 days';
    RAISE NOTICE '   3. ✅ Updated last_reward_calculated timestamps';
    RAISE NOTICE '   4. ✅ Cron job will now generate both NFT and token rewards daily';
    RAISE NOTICE '';
    RAISE NOTICE '💰 Expected Result:';
    RAISE NOTICE '   - Your missing ~1.26 NEFT token rewards should now be claimable';
    RAISE NOTICE '   - Future token rewards will generate daily at midnight UTC';
    RAISE NOTICE '   - Both NFT and token rewards work together';
    RAISE NOTICE '';
END $$;
