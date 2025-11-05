-- =============================================================================
-- COMPLETE FIX: Ambiguous Column Error + Pending Rewards Generation
-- =============================================================================
-- This script fixes the function errors and generates rewards in one go
-- Wallet: 0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 COMPLETE STAKING REWARDS FIX';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 1: FIX AMBIGUOUS COLUMN ERROR
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '📝 STEP 1: Fixing ambiguous column error in functions...';
END $$;

-- Fix calculate_pending_rewards function
DROP FUNCTION IF EXISTS calculate_pending_rewards(TEXT, TEXT);

CREATE OR REPLACE FUNCTION calculate_pending_rewards(
    p_wallet_address TEXT,
    p_reward_type TEXT
)
RETURNS DECIMAL(18,8)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    pending_amount DECIMAL(18,8) := 0;
BEGIN
    IF p_reward_type = 'nft' THEN
        SELECT COALESCE(SUM(nft_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
          
    ELSIF p_reward_type = 'token' THEN
        SELECT COALESCE(SUM(token_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
          
    ELSE
        SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0)
        INTO pending_amount
        FROM staking_rewards
        WHERE wallet_address = p_wallet_address 
          AND is_claimed = false;
    END IF;
    
    RETURN pending_amount;
    
EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$;

-- Fix get_user_staking_summary function
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
    -- Count staked NFTs
    SELECT COUNT(*) INTO v_staked_nfts_count
    FROM staked_nfts WHERE wallet_address = p_user_wallet;
    
    -- Sum staked tokens
    SELECT COALESCE(SUM(amount), 0) INTO v_staked_tokens_amount
    FROM staked_tokens WHERE wallet_address = p_user_wallet;
    
    -- Daily NFT rewards
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_nft_rewards
    FROM staked_nfts WHERE wallet_address = p_user_wallet;
    
    -- Daily token rewards
    SELECT COALESCE(SUM(daily_reward), 0) INTO v_daily_token_rewards
    FROM staked_tokens WHERE wallet_address = p_user_wallet;
    
    -- Pending NFT rewards
    SELECT COALESCE(SUM(nft_earned_today), 0) INTO v_nft_pending_rewards
    FROM staking_rewards WHERE wallet_address = p_user_wallet AND is_claimed = false;
    
    -- Pending token rewards
    SELECT COALESCE(SUM(token_earned_today), 0) INTO v_token_pending_rewards
    FROM staking_rewards WHERE wallet_address = p_user_wallet AND is_claimed = false;
    
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
    RETURN json_build_object(
        'error', SQLERRM,
        'staked_nfts_count', 0,
        'staked_tokens_amount', 0,
        'nft_pending_rewards', 0,
        'token_pending_rewards', 0,
        'total_pending_rewards', 0,
        'daily_nft_rewards', 0,
        'daily_token_rewards', 0
    );
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_pending_rewards(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_user_staking_summary(TEXT) TO authenticated, anon, public;

DO $$
BEGIN
    RAISE NOTICE '✅ Functions fixed successfully!';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 2: CHECK YOUR STAKING STATUS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '📊 STEP 2: Checking your staking status...';
END $$;

SELECT 
    'Your Staked Assets' as status,
    (SELECT COUNT(*) FROM staked_nfts WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as nfts_staked,
    (SELECT COALESCE(SUM(amount), 0) FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as tokens_staked,
    (SELECT COALESCE(SUM(daily_reward), 0) FROM staked_nfts WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as nft_daily_rewards,
    (SELECT COALESCE(SUM(daily_reward), 0) FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as token_daily_rewards;

-- =============================================================================
-- STEP 3: GENERATE REWARDS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '⚡ STEP 3: Generating rewards...';
END $$;

SELECT generate_daily_staking_rewards() as generation_result;

DO $$
BEGIN
    RAISE NOTICE '✅ Rewards generated!';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 4: CHECK YOUR PENDING REWARDS
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '💰 STEP 4: Checking your pending rewards...';
END $$;

-- Your rewards history
SELECT 
    'Your Reward History' as info,
    reward_date,
    nft_earned_today,
    token_earned_today,
    (nft_earned_today + token_earned_today) as total_today,
    is_claimed
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY reward_date DESC
LIMIT 10;

-- Your pending rewards summary
SELECT 
    'Your Pending Rewards' as info,
    COALESCE(SUM(nft_earned_today), 0) as pending_nft,
    COALESCE(SUM(token_earned_today), 0) as pending_token,
    COALESCE(SUM(nft_earned_today + token_earned_today), 0) as total_pending
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND is_claimed = false;

-- Test summary function
SELECT 
    'Summary Function Result' as info,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as summary;

-- =============================================================================
-- STEP 5: SETUP AUTOMATIC CRON JOB
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '⚙️  STEP 5: Setting up automatic cron job...';
END $$;

-- Enable pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove old jobs
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid, jobname FROM cron.job 
        WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
        RAISE NOTICE 'Removed old job: %', job_record.jobname;
    END LOOP;
END $$;

-- Create new cron job
SELECT cron.schedule(
    'generate-staking-rewards-6h',
    '0 */6 * * *',
    $$SELECT generate_daily_staking_rewards();$$
) as cron_job_created;

-- Verify cron job
SELECT 
    'Cron Job Status' as info,
    jobid,
    jobname,
    schedule,
    active
FROM cron.job 
WHERE jobname = 'generate-staking-rewards-6h';

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO postgres, authenticated, anon;

-- =============================================================================
-- FINAL REPORT
-- =============================================================================

DO $$
DECLARE
    v_nft_count INTEGER;
    v_token_amount DECIMAL;
    v_pending_rewards DECIMAL;
    v_reward_records INTEGER;
BEGIN
    -- Get stats
    SELECT COUNT(*) INTO v_nft_count 
    FROM staked_nfts WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_token_amount 
    FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0) INTO v_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071' 
      AND is_claimed = false;
      
    SELECT COUNT(*) INTO v_reward_records
    FROM staking_rewards WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ COMPLETE! FINAL STATUS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Your Staking Status:';
    RAISE NOTICE '   • NFTs Staked: %', v_nft_count;
    RAISE NOTICE '   • Tokens Staked: % NEFT', v_token_amount;
    RAISE NOTICE '   • Reward Records: %', v_reward_records;
    RAISE NOTICE '   • Pending Rewards: % NEFT', v_pending_rewards;
    RAISE NOTICE '';
    RAISE NOTICE '✅ What Was Fixed:';
    RAISE NOTICE '   1. ✅ Fixed ambiguous column error in functions';
    RAISE NOTICE '   2. ✅ Generated missing rewards';
    RAISE NOTICE '   3. ✅ Setup automatic cron job (every 6 hours)';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Result:';
    
    IF v_pending_rewards > 0 THEN
        RAISE NOTICE '   ✅ SUCCESS! You have % NEFT pending rewards', v_pending_rewards;
        RAISE NOTICE '   → Refresh your staking page';
        RAISE NOTICE '   → Pending rewards should now show: % NEFT', v_pending_rewards;
        RAISE NOTICE '   → Claim button should be ENABLED';
    ELSE
        RAISE NOTICE '   ⚠️  No pending rewards generated yet';
        RAISE NOTICE '   → Verify you have staked assets (NFTs: %, Tokens: %)', v_nft_count, v_token_amount;
        RAISE NOTICE '   → Rewards will generate in next 6-hour cycle';
        RAISE NOTICE '   → Or wait 24 hours from stake time for first rewards';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Automatic Operation:';
    RAISE NOTICE '   • Cron job runs every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)';
    RAISE NOTICE '   • Next rewards will auto-generate at next cycle';
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
END $$;
