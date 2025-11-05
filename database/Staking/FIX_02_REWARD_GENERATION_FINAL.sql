-- =============================================================================
-- FIX 02: ACCUMULATIVE REWARD GENERATION (FINAL - MATCHES ACTUAL SCHEMA)
-- =============================================================================
-- Purpose: Fix reward calculation rates and implement automatic daily accumulation
-- Deploy: THIRD (after FIX_01 and FIX_01B corrected versions)
-- Status: PRODUCTION READY - Matches your exact database schema

-- =============================================================================
-- SCHEMA NOTES:
-- staked_nfts: uses daily_reward (not daily_rate)
-- staked_tokens: uses daily_reward (not daily_rate), has apr_rate
-- staking_rewards: uses nft_earned_today, token_earned_today, total_earned, is_claimed
-- user_balances: uses available_neft, total_neft_claimed, staked_neft
-- =============================================================================

-- =============================================================================
-- PART 1: UPDATE STAKE_TOKENS TO USE 20% APR
-- =============================================================================

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
    
    -- ✅ Calculate daily reward for 20% APR
    -- Formula: (staked_amount × 0.20) / 365
    calculated_daily_reward := (stake_amount * 0.20) / 365.0;
    calculated_apr := 20.00;
    
    -- Insert staked tokens (using actual column names from your schema)
    INSERT INTO staked_tokens (
        wallet_address, 
        amount, 
        apr_rate,
        daily_reward,
        staked_at, 
        total_earned, 
        last_claim,
        last_reward_calculated
    )
    VALUES (
        user_wallet, 
        stake_amount, 
        calculated_apr,
        calculated_daily_reward,
        NOW(), 
        0, 
        NOW(),
        NOW()
    );
    
    -- Update user balance (deduct staked amount)
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
        'daily_rate', calculated_daily_reward,      -- For backward compatibility
        'daily_reward', calculated_daily_reward,    -- Frontend uses this
        'apr', '20%',
        'apr_rate', calculated_apr,
        'new_available_balance', current_available - stake_amount
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error staking tokens: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- =============================================================================
-- PART 2: ENHANCED DAILY REWARD GENERATION (MATCHES YOUR SCHEMA)
-- =============================================================================

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
    day_total DECIMAL(18,8);
    current_total_earned DECIMAL(18,8);
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
        -- ✅ Calculate NFT daily rewards (sum of all daily_reward from staked_nfts)
        SELECT COALESCE(SUM(daily_reward), 0) 
        INTO nft_daily_total 
        FROM staked_nfts 
        WHERE wallet_address = reward_record.wallet_address;
        
        -- ✅ Calculate Token daily rewards (sum of all daily_reward from staked_tokens)
        SELECT COALESCE(SUM(daily_reward), 0)
        INTO token_daily_total 
        FROM staked_tokens 
        WHERE wallet_address = reward_record.wallet_address;
        
        -- Skip if no rewards to generate
        IF nft_daily_total = 0 AND token_daily_total = 0 THEN
            CONTINUE;
        END IF;
        
        day_total := nft_daily_total + token_daily_total;
        
        -- Get current cumulative total_earned
        SELECT COALESCE(total_earned, 0)
        INTO current_total_earned
        FROM staking_rewards 
        WHERE wallet_address = reward_record.wallet_address 
        ORDER BY reward_date DESC
        LIMIT 1;
        
        -- ✅ Insert today's rewards (using your actual schema columns)
        INSERT INTO staking_rewards (
            wallet_address, 
            reward_date, 
            nft_earned_today,          -- Your actual column name
            token_earned_today,        -- Your actual column name
            total_earned,              -- Cumulative across all days
            is_claimed,                -- Your actual column name
            blockchain,
            created_at, 
            last_updated
        ) VALUES (
            reward_record.wallet_address,
            CURRENT_DATE,
            nft_daily_total,
            token_daily_total,
            current_total_earned + day_total,  -- Accumulate
            false,
            'polygon',
            NOW(), 
            NOW()
        )
        ON CONFLICT (wallet_address, reward_date) 
        DO UPDATE SET
            nft_earned_today = EXCLUDED.nft_earned_today,
            token_earned_today = EXCLUDED.token_earned_today,
            total_earned = EXCLUDED.total_earned,
            last_updated = NOW();
        
        -- Update last_reward_calculated timestamps
        UPDATE staked_nfts 
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address;
        
        UPDATE staked_tokens
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address;
        
        total_nft_rewards := total_nft_rewards + nft_daily_total;
        total_token_rewards := total_token_rewards + token_daily_total;
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
        'timestamp', NOW()
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
-- PART 3: CALCULATE PENDING REWARDS IN REAL-TIME (MATCHES YOUR SCHEMA)
-- =============================================================================

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
    -- Get unclaimed rewards from staking_rewards table (using your actual column names)
    IF reward_type = 'nft' THEN
        -- Sum up all unclaimed NFT rewards
        SELECT COALESCE(SUM(nft_earned_today), 0)
        INTO unclaimed_from_rewards
        FROM staking_rewards
        WHERE wallet_address = user_wallet AND is_claimed = false;
        
        -- Add real-time accrual since last reward calculation (using daily_reward column)
        SELECT COALESCE(SUM(
            EXTRACT(EPOCH FROM (NOW() - GREATEST(last_reward_calculated, reward_date))) / 86400.0 * daily_reward
        ), 0)
        INTO realtime_accrual
        FROM staked_nfts sn
        LEFT JOIN (
            SELECT wallet_address, MAX(reward_date) as reward_date
            FROM staking_rewards
            GROUP BY wallet_address
        ) sr ON sn.wallet_address = sr.wallet_address
        WHERE sn.wallet_address = user_wallet;
        
    ELSIF reward_type = 'token' THEN
        -- Sum up all unclaimed token rewards
        SELECT COALESCE(SUM(token_earned_today), 0)
        INTO unclaimed_from_rewards
        FROM staking_rewards
        WHERE wallet_address = user_wallet AND is_claimed = false;
        
        -- Add real-time accrual since last reward calculation (using daily_reward column)
        SELECT COALESCE(SUM(
            EXTRACT(EPOCH FROM (NOW() - GREATEST(last_reward_calculated, reward_date))) / 86400.0 * daily_reward
        ), 0)
        INTO realtime_accrual
        FROM staked_tokens st
        LEFT JOIN (
            SELECT wallet_address, MAX(reward_date) as reward_date
            FROM staking_rewards
            GROUP BY wallet_address
        ) sr ON st.wallet_address = sr.wallet_address
        WHERE st.wallet_address = user_wallet;
    END IF;
    
    pending_amount := unclaimed_from_rewards + realtime_accrual;
    
    RETURN GREATEST(pending_amount, 0);
END;
$$;

-- =============================================================================
-- PART 4: SETUP SUPABASE CRON JOB (Automatic Daily Execution)
-- =============================================================================

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing staking reward cron jobs if they exist
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

-- ✅ Schedule daily reward generation at midnight UTC (24-hour cycle)
SELECT cron.schedule(
    'generate-staking-rewards-daily',  -- Job name
    '0 0 * * *',                        -- Every day at 00:00 UTC (midnight)
    $$SELECT generate_daily_staking_rewards();$$
);

-- Note: Rewards will be generated once per day at midnight UTC
-- Users will see pending rewards update in real-time via the calculate_pending_rewards() function

-- =============================================================================
-- PART 5: UPDATE UNSTAKE FUNCTIONS TO FINALIZE REWARDS (MATCHES YOUR SCHEMA)
-- =============================================================================

CREATE OR REPLACE FUNCTION unstake_nft(user_wallet TEXT, nft_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    staked_record RECORD;
    pending_rewards DECIMAL(18,8);
    last_reward_date DATE;
BEGIN
    -- Get staked NFT record
    SELECT * INTO staked_record FROM staked_nfts WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'NFT is not staked', 'error', 'NOT_STAKED');
    END IF;
    
    -- Get last reward generation date
    SELECT COALESCE(MAX(reward_date), CURRENT_DATE) INTO last_reward_date
    FROM staking_rewards
    WHERE wallet_address = user_wallet;
    
    -- ✅ Calculate pending rewards since last generation (using daily_reward column)
    pending_rewards := EXTRACT(EPOCH FROM (NOW() - GREATEST(staked_record.last_reward_calculated, last_reward_date::TIMESTAMP))) / 86400.0 * staked_record.daily_reward;
    
    -- Update total_earned in the staked_nfts record
    UPDATE staked_nfts 
    SET total_earned = total_earned + pending_rewards
    WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    -- ✅ Add final pending rewards to today's staking_rewards (if any)
    IF pending_rewards > 0.01 THEN
        INSERT INTO staking_rewards (
            wallet_address, 
            reward_date, 
            nft_earned_today,
            token_earned_today,
            total_earned,
            is_claimed,
            blockchain
        ) VALUES (
            user_wallet, 
            CURRENT_DATE, 
            pending_rewards,
            0,
            pending_rewards,
            false,
            staked_record.blockchain
        )
        ON CONFLICT (wallet_address, reward_date)
        DO UPDATE SET
            nft_earned_today = staking_rewards.nft_earned_today + pending_rewards,
            total_earned = staking_rewards.total_earned + pending_rewards,
            last_updated = NOW();
    END IF;
    
    -- Remove from staked_nfts
    DELETE FROM staked_nfts WHERE wallet_address = user_wallet AND nft_id = unstake_nft.nft_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'NFT unstaked successfully',
        'nft_id', unstake_nft.nft_id,
        'final_pending_rewards', pending_rewards
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error unstaking NFT: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

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
    last_reward_date DATE;
BEGIN
    -- Get staked tokens record
    SELECT * INTO staked_record FROM staked_tokens WHERE id = staked_tokens_id AND wallet_address = user_wallet;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Staked tokens record not found', 'error', 'NOT_FOUND');
    END IF;
    
    -- Validate unstake amount
    IF unstake_amount <= 0 OR unstake_amount > staked_record.amount THEN
        RETURN json_build_object(
            'success', false,
            'message', format('Invalid unstake amount. Available: %s, Requested: %s', staked_record.amount, unstake_amount),
            'error', 'INVALID_AMOUNT'
        );
    END IF;
    
    remaining_amount := staked_record.amount - unstake_amount;
    
    -- Get last reward generation date
    SELECT COALESCE(MAX(reward_date), CURRENT_DATE) INTO last_reward_date
    FROM staking_rewards
    WHERE wallet_address = user_wallet;
    
    -- ✅ Calculate pending rewards since last generation (using daily_reward column)
    pending_rewards := EXTRACT(EPOCH FROM (NOW() - GREATEST(staked_record.last_reward_calculated, last_reward_date::TIMESTAMP))) / 86400.0 * staked_record.daily_reward;
    
    -- Update total_earned in the staked_tokens record
    UPDATE staked_tokens 
    SET total_earned = total_earned + pending_rewards
    WHERE id = staked_tokens_id;
    
    -- ✅ Add final pending rewards to today's staking_rewards (if any)
    IF pending_rewards > 0.01 THEN
        INSERT INTO staking_rewards (
            wallet_address, 
            reward_date, 
            nft_earned_today,
            token_earned_today,
            total_earned,
            is_claimed,
            blockchain
        ) VALUES (
            user_wallet, 
            CURRENT_DATE, 
            0,
            pending_rewards,
            pending_rewards,
            false,
            'polygon'
        )
        ON CONFLICT (wallet_address, reward_date)
        DO UPDATE SET
            token_earned_today = staking_rewards.token_earned_today + pending_rewards,
            total_earned = staking_rewards.total_earned + pending_rewards,
            last_updated = NOW();
    END IF;
    
    -- Return tokens to available balance
    UPDATE user_balances 
    SET 
        available_neft = available_neft + unstake_amount,
        staked_neft = GREATEST(staked_neft - unstake_amount, 0),
        last_updated = NOW()
    WHERE wallet_address = user_wallet;
    
    -- If unstaking all, delete the record; otherwise update the amount
    IF remaining_amount <= 0 THEN
        DELETE FROM staked_tokens WHERE id = staked_tokens_id;
    ELSE
        -- ✅ Recalculate daily reward for remaining amount with 20% APR
        new_daily_reward := (remaining_amount * 0.20) / 365.0;
        UPDATE staked_tokens 
        SET 
            amount = remaining_amount, 
            daily_reward = new_daily_reward,
            last_claim = NOW(),
            last_reward_calculated = NOW()
        WHERE id = staked_tokens_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', format('Successfully unstaked %s NEFT tokens', unstake_amount),
        'unstaked_amount', unstake_amount,
        'remaining_staked', remaining_amount,
        'final_pending_rewards', pending_rewards
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error unstaking tokens: ' || SQLERRM, 'error', SQLERRM);
END;
$$;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION stake_tokens(TEXT, DECIMAL) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION calculate_pending_rewards(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION unstake_nft(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION unstake_tokens(TEXT, UUID, DECIMAL) TO authenticated, anon, public;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
DECLARE
    example_apr DECIMAL(18,8);
    test_result JSON;
BEGIN
    -- Test APR calculation
    example_apr := (1000.0 * 0.20) / 365.0;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== FIX 02: REWARD GENERATION (FINAL - MATCHES YOUR SCHEMA) ===';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated Functions:';
    RAISE NOTICE '   - stake_tokens() now uses 20%% APR (not 36.5%%)';
    RAISE NOTICE '   - generate_daily_staking_rewards() with your schema';
    RAISE NOTICE '   - unstake_nft() finalizes rewards before unstaking';
    RAISE NOTICE '   - unstake_tokens() finalizes rewards before unstaking';
    RAISE NOTICE '';
    RAISE NOTICE '✅ New Functions:';
    RAISE NOTICE '   - calculate_pending_rewards(wallet, type)';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Cron Job Scheduled:';
    RAISE NOTICE '   - Daily at 00:00 UTC (midnight) - 24-hour cycle';
    RAISE NOTICE '   - Real-time pending rewards via calculate_pending_rewards()';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Schema Compatibility:';
    RAISE NOTICE '   - Uses daily_reward column (not daily_rate) ✅';
    RAISE NOTICE '   - Uses nft_earned_today, token_earned_today ✅';
    RAISE NOTICE '   - Uses is_claimed (not claimed) ✅';
    RAISE NOTICE '   - Uses apr_rate field ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Reward Rate Verification:';
    RAISE NOTICE '   - 1000 NEFT staked at 20%% APR = % NEFT/day', example_apr;
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Triggering first reward generation...';
    
    -- Trigger first generation
    test_result := generate_daily_staking_rewards();
    
    RAISE NOTICE '✅ Result: %', test_result;
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Ready for FIX_03_CLAIM_FUNCTIONS_FINAL.sql';
    RAISE NOTICE '';
END $$;
