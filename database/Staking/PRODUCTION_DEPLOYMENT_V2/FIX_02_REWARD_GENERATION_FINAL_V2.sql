-- =============================================================================
-- FIX 02: ACCUMULATIVE REWARD GENERATION (FINAL V2 - SEPARATE NFT/TOKEN)
-- =============================================================================
-- Purpose: Generate separate rows for NFT and Token rewards for independent claiming
-- Deploy: THIRD (after FIX_01 and FIX_01B corrected versions)
-- Status: PRODUCTION READY - Supports separate NFT/Token claims

-- =============================================================================
-- SCHEMA STRATEGY:
-- Use reward_type field to create separate rows for 'nft' and 'token' rewards
-- This allows claiming NFT rewards independently from token rewards
-- =============================================================================

-- Same stake_tokens function as before
CREATE OR REPLACE FUNCTION stake_tokens(user_wallet TEXT, stake_amount DECIMAL(18,8))
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_available DECIMAL(18,8) := 0;
    calculated_daily_reward DECIMAL(18,8);
    calculated_apr DECIMAL(5,2);
BEGIN
    -- Validate amount
    IF stake_amount <= 0 THEN
        RETURN json_build_object('success', false, 'message', 'Stake amount must be greater than 0', 'error', 'INVALID_AMOUNT');
    END IF;
    
    -- Get current available balance
    SELECT COALESCE(available_neft, 0) INTO current_available FROM user_balances WHERE wallet_address = user_wallet;
    
    -- Check sufficient balance
    IF current_available < stake_amount THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Insufficient balance. Available: %s, Required: %s', current_available, stake_amount),
            'error', 'INSUFFICIENT_BALANCE'
        );
    END IF;
    
    -- Calculate daily reward for 20% APR
    calculated_daily_reward := (stake_amount * 0.20) / 365.0;
    calculated_apr := 20.00;
    
    -- Insert staked tokens
    INSERT INTO staked_tokens (
        wallet_address, amount, apr_rate, daily_reward,
        staked_at, total_earned, last_claim, last_reward_calculated
    )
    VALUES (
        user_wallet, stake_amount, calculated_apr, calculated_daily_reward,
        NOW(), 0, NOW(), NOW()
    );
    
    -- Update user balance
    UPDATE user_balances 
    SET 
        available_neft = available_neft - stake_amount,
        staked_neft = COALESCE(staked_neft, 0) + stake_amount,
        last_updated = NOW()
    WHERE wallet_address = user_wallet;
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully staked %s NEFT tokens at 20%% APR', stake_amount),
        'staked_amount', stake_amount,
        'daily_rate', calculated_daily_reward,
        'daily_reward', calculated_daily_reward,
        'apr', '20%',
        'apr_rate', calculated_apr,
        'new_available_balance', current_available - stake_amount
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error staking tokens: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- =============================================================================
-- ENHANCED DAILY REWARD GENERATION - SEPARATE NFT & TOKEN ROWS
-- =============================================================================

-- Drop existing function if it exists (handles return type changes)
DROP FUNCTION IF EXISTS generate_daily_staking_rewards();

CREATE OR REPLACE FUNCTION generate_daily_staking_rewards()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    reward_record RECORD;
    rewards_generated INTEGER := 0;
    nft_daily_total DECIMAL(18,8);
    token_daily_total DECIMAL(18,8);
    total_nft_rewards DECIMAL(18,8) := 0;
    total_token_rewards DECIMAL(18,8) := 0;
BEGIN
    RAISE NOTICE '🔄 Starting daily staking reward generation at %', NOW();
    
    -- Process rewards for each wallet with staked assets
    FOR reward_record IN (
        SELECT DISTINCT wallet_address FROM (
            SELECT wallet_address FROM staked_nfts 
            UNION 
            SELECT wallet_address FROM staked_tokens
        ) AS all_stakers
    ) LOOP
        -- Calculate NFT daily rewards
        SELECT COALESCE(SUM(daily_reward), 0) 
        INTO nft_daily_total 
        FROM staked_nfts 
        WHERE wallet_address = reward_record.wallet_address;
        
        -- Calculate Token daily rewards
        SELECT COALESCE(SUM(daily_reward), 0)
        INTO token_daily_total 
        FROM staked_tokens 
        WHERE wallet_address = reward_record.wallet_address;
        
        -- ✅ Create SEPARATE row for NFT rewards (if any)
        IF nft_daily_total > 0 THEN
            INSERT INTO staking_rewards (
                wallet_address, 
                reward_date, 
                reward_type,           -- 'nft'
                reward_amount,         -- Use this for the specific type amount
                nft_earned_today,      -- Also populate the daily field
                token_earned_today,    -- 0 for NFT-only row
                total_earned,          -- Just NFT amount for this row
                is_claimed,
                blockchain,
                created_at, 
                last_updated
            ) VALUES (
                reward_record.wallet_address,
                CURRENT_DATE,
                'nft',                 -- Mark as NFT reward
                nft_daily_total,
                nft_daily_total,
                0,                     -- No token rewards in this row
                nft_daily_total,
                false,
                'polygon',
                NOW(), 
                NOW()
            )
            ON CONFLICT (wallet_address, reward_date, reward_type, source_id) 
            DO UPDATE SET
                reward_amount = EXCLUDED.reward_amount,
                nft_earned_today = EXCLUDED.nft_earned_today,
                total_earned = EXCLUDED.total_earned,
                last_updated = NOW();
            
            total_nft_rewards := total_nft_rewards + nft_daily_total;
        END IF;
        
        -- ✅ Create SEPARATE row for Token rewards (if any)
        IF token_daily_total > 0 THEN
            INSERT INTO staking_rewards (
                wallet_address, 
                reward_date, 
                reward_type,           -- 'token'
                reward_amount,         -- Use this for the specific type amount
                nft_earned_today,      -- 0 for Token-only row
                token_earned_today,    -- Token rewards
                total_earned,          -- Just token amount for this row
                is_claimed,
                blockchain,
                created_at, 
                last_updated
            ) VALUES (
                reward_record.wallet_address,
                CURRENT_DATE,
                'token',               -- Mark as Token reward
                token_daily_total,
                0,                     -- No NFT rewards in this row
                token_daily_total,
                token_daily_total,
                false,
                'polygon',
                NOW(), 
                NOW()
            )
            ON CONFLICT (wallet_address, reward_date, reward_type, source_id) 
            DO UPDATE SET
                reward_amount = EXCLUDED.reward_amount,
                token_earned_today = EXCLUDED.token_earned_today,
                total_earned = EXCLUDED.total_earned,
                last_updated = NOW();
            
            total_token_rewards := total_token_rewards + token_daily_total;
        END IF;
        
        -- Update last_reward_calculated timestamps
        UPDATE staked_nfts 
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address;
        
        UPDATE staked_tokens
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address;
        
        rewards_generated := rewards_generated + 1;
        
        RAISE NOTICE '  ✅ Generated rewards for %: NFT=%, Token=%', 
            reward_record.wallet_address, nft_daily_total, token_daily_total;
    END LOOP;
    
    RAISE NOTICE '✅ Daily reward generation complete';
    RAISE NOTICE '   - Wallets processed: %', rewards_generated;
    RAISE NOTICE '   - Total NFT rewards: % NEFT', total_nft_rewards;
    RAISE NOTICE '   - Total Token rewards: % NEFT', total_token_rewards;
    
    RETURN json_build_object(
        'success', true,
        'wallets_processed', rewards_generated,
        'total_nft_rewards', total_nft_rewards,
        'total_token_rewards', total_token_rewards,
        'timestamp', NOW(),
        'note', 'Separate rows created for NFT and Token rewards'
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error generating daily rewards: %', SQLERRM;
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- =============================================================================
-- CALCULATE PENDING REWARDS (SEPARATE BY TYPE)
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS calculate_pending_rewards(TEXT, TEXT);

CREATE OR REPLACE FUNCTION calculate_pending_rewards(user_wallet TEXT, reward_type TEXT)
RETURNS DECIMAL(18,8)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    pending_amount DECIMAL(18,8) := 0;
    unclaimed_from_rewards DECIMAL(18,8) := 0;
    realtime_accrual DECIMAL(18,8) := 0;
BEGIN
    IF reward_type = 'nft' THEN
        -- Sum unclaimed NFT rewards from NFT-specific rows
        SELECT COALESCE(SUM(reward_amount), 0)
        INTO unclaimed_from_rewards
        FROM staking_rewards
        WHERE wallet_address = user_wallet 
        AND reward_type = 'nft'
        AND is_claimed = false;
        
        -- Add real-time accrual
        SELECT COALESCE(SUM(
            EXTRACT(EPOCH FROM (NOW() - last_reward_calculated)) / 86400.0 * daily_reward
        ), 0)
        INTO realtime_accrual
        FROM staked_nfts
        WHERE wallet_address = user_wallet;
        
    ELSIF reward_type = 'token' THEN
        -- Sum unclaimed token rewards from token-specific rows
        SELECT COALESCE(SUM(reward_amount), 0)
        INTO unclaimed_from_rewards
        FROM staking_rewards
        WHERE wallet_address = user_wallet 
        AND reward_type = 'token'
        AND is_claimed = false;
        
        -- Add real-time accrual
        SELECT COALESCE(SUM(
            EXTRACT(EPOCH FROM (NOW() - last_reward_calculated)) / 86400.0 * daily_reward
        ), 0)
        INTO realtime_accrual
        FROM staked_tokens
        WHERE wallet_address = user_wallet;
    END IF;
    
    pending_amount := unclaimed_from_rewards + realtime_accrual;
    
    RETURN GREATEST(pending_amount, 0);
END;
$$;

-- Cron setup and unstake functions remain the same as previous version
-- (Including them for completeness)

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing cron jobs
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid, jobname FROM cron.job 
        WHERE jobname IN ('generate-staking-rewards', 'generate-staking-rewards-6h', 'generate-staking-rewards-daily')
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
        RAISE NOTICE 'Removed existing cron job: %', job_record.jobname;
    END LOOP;
END $$;

-- Schedule daily reward generation
SELECT cron.schedule(
    'generate-staking-rewards-daily',
    '0 0 * * *',
    $$SELECT generate_daily_staking_rewards();$$
);

-- Unstake functions (same as before, shortened for brevity)
-- Drop existing function if it exists
DROP FUNCTION IF EXISTS unstake_nft(TEXT, TEXT);

CREATE OR REPLACE FUNCTION unstake_nft(user_wallet TEXT, nft_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    staked_record RECORD;
    pending_rewards DECIMAL(18,8);
BEGIN
    SELECT * INTO staked_record FROM staked_nfts WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'NFT is not staked', 'error', 'NOT_STAKED');
    END IF;
    
    pending_rewards := EXTRACT(EPOCH FROM (NOW() - staked_record.last_reward_calculated)) / 86400.0 * staked_record.daily_reward;
    
    UPDATE staked_nfts SET total_earned = total_earned + pending_rewards WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    IF pending_rewards > 0.01 THEN
        INSERT INTO staking_rewards (
            wallet_address, reward_date, reward_type, reward_amount,
            nft_earned_today, token_earned_today, total_earned, is_claimed, blockchain
        ) VALUES (
            user_wallet, CURRENT_DATE, 'nft', pending_rewards,
            pending_rewards, 0, pending_rewards, false, staked_record.blockchain
        )
        ON CONFLICT (wallet_address, reward_date, reward_type, source_id)
        DO UPDATE SET
            reward_amount = staking_rewards.reward_amount + pending_rewards,
            nft_earned_today = staking_rewards.nft_earned_today + pending_rewards,
            total_earned = staking_rewards.total_earned + pending_rewards,
            last_updated = NOW();
    END IF;
    
    DELETE FROM staked_nfts WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    RETURN json_build_object('success', true, 'message', 'NFT unstaked successfully', 'nft_id', unstake_nft.nft_id, 'final_pending_rewards', pending_rewards);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error unstaking NFT: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS unstake_tokens(TEXT, UUID, DECIMAL);

CREATE OR REPLACE FUNCTION unstake_tokens(user_wallet TEXT, staked_tokens_id UUID, unstake_amount DECIMAL(18,8))
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    staked_record RECORD;
    remaining_amount DECIMAL(18,8);
    pending_rewards DECIMAL(18,8);
    new_daily_reward DECIMAL(18,8);
BEGIN
    SELECT * INTO staked_record FROM staked_tokens WHERE id = staked_tokens_id AND wallet_address = user_wallet;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Staked tokens record not found', 'error', 'NOT_FOUND');
    END IF;
    
    IF unstake_amount <= 0 OR unstake_amount > staked_record.amount THEN
        RETURN json_build_object('success', false, 'message', format('Invalid unstake amount. Available: %s, Requested: %s', staked_record.amount, unstake_amount), 'error', 'INVALID_AMOUNT');
    END IF;
    
    remaining_amount := staked_record.amount - unstake_amount;
    pending_rewards := EXTRACT(EPOCH FROM (NOW() - staked_record.last_reward_calculated)) / 86400.0 * staked_record.daily_reward;
    
    UPDATE staked_tokens SET total_earned = total_earned + pending_rewards WHERE id = staked_tokens_id;
    
    IF pending_rewards > 0.01 THEN
        INSERT INTO staking_rewards (
            wallet_address, reward_date, reward_type, reward_amount,
            nft_earned_today, token_earned_today, total_earned, is_claimed, blockchain
        ) VALUES (
            user_wallet, CURRENT_DATE, 'token', pending_rewards,
            0, pending_rewards, pending_rewards, false, 'polygon'
        )
        ON CONFLICT (wallet_address, reward_date, reward_type, source_id)
        DO UPDATE SET
            reward_amount = staking_rewards.reward_amount + pending_rewards,
            token_earned_today = staking_rewards.token_earned_today + pending_rewards,
            total_earned = staking_rewards.total_earned + pending_rewards,
            last_updated = NOW();
    END IF;
    
    UPDATE user_balances SET available_neft = available_neft + unstake_amount, staked_neft = GREATEST(staked_neft - unstake_amount, 0), last_updated = NOW() WHERE wallet_address = user_wallet;
    
    IF remaining_amount <= 0 THEN
        DELETE FROM staked_tokens WHERE id = staked_tokens_id;
    ELSE
        new_daily_reward := (remaining_amount * 0.20) / 365.0;
        UPDATE staked_tokens SET amount = remaining_amount, daily_reward = new_daily_reward, last_claim = NOW(), last_reward_calculated = NOW() WHERE id = staked_tokens_id;
    END IF;
    
    RETURN json_build_object('success', true, 'message', format('Successfully unstaked %s NEFT tokens', unstake_amount), 'unstaked_amount', unstake_amount, 'remaining_staked', remaining_amount, 'final_pending_rewards', pending_rewards);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error unstaking tokens: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION stake_tokens(TEXT, DECIMAL) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION calculate_pending_rewards(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION unstake_nft(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION unstake_tokens(TEXT, UUID, DECIMAL) TO authenticated, anon, public;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== FIX 02: REWARD GENERATION V2 - SEPARATE NFT/TOKEN CLAIMS ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Key Feature: Separate rows for NFT and Token rewards';
    RAISE NOTICE '✅ Allows claiming NFT rewards independently from tokens';
    RAISE NOTICE '✅ Uses reward_type field (''nft'' or ''token'')';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_03_CLAIM_FUNCTIONS_FINAL_V2.sql';
    RAISE NOTICE '';
END $$;
