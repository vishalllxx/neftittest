-- ============================================================================
-- TEST CRON JOB REWARD GENERATION IN SUPABASE
-- ============================================================================
-- Check if rewards are being generated properly by cron jobs
-- ============================================================================

-- 1. Check if cron extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- 2. Check existing cron jobs related to staking rewards
SELECT 
    jobid,
    schedule,
    command,
    nodename,
    nodeport,
    database,
    username,
    active,
    jobname
FROM cron.job 
WHERE command LIKE '%staking%' 
   OR command LIKE '%reward%' 
   OR jobname LIKE '%staking%'
   OR jobname LIKE '%reward%';

-- 3. Check recent cron job execution history
SELECT 
    jrd.jobid,
    j.jobname,
    j.command,
    jrd.start_time,
    jrd.end_time,
    jrd.return_message,
    jrd.status
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.command LIKE '%staking%' 
   OR j.command LIKE '%reward%'
   OR j.jobname LIKE '%staking%'
   OR j.jobname LIKE '%reward%'
ORDER BY jrd.start_time DESC 
LIMIT 10;

-- 4. Check if generate_daily_staking_rewards function exists
SELECT 
    routine_name,
    routine_type,
    data_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'generate_daily_staking_rewards';

-- 5. Test the reward generation function manually
SELECT 
    'Manual Test Result' as test_type,
    generate_daily_staking_rewards() as rewards_generated,
    NOW() as test_time;

-- 6. Check recent reward generation activity
SELECT 
    reward_date,
    COUNT(DISTINCT wallet_address) as wallets_with_rewards,
    COUNT(*) as total_reward_records,
    SUM(total_earned) as total_neft_generated,
    MIN(created_at) as first_generated,
    MAX(created_at) as last_generated
FROM staking_rewards
WHERE reward_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY reward_date
ORDER BY reward_date DESC;

-- 7. Check if rewards were generated today
SELECT 
    'Today Rewards Check' as check_type,
    COUNT(*) as reward_records_today,
    COUNT(DISTINCT wallet_address) as wallets_rewarded_today,
    SUM(total_earned) as total_rewards_today
FROM staking_rewards
WHERE reward_date = CURRENT_DATE;

-- 8. Check users with staked assets (should generate rewards)
SELECT 
    'Staked Assets Check' as check_type,
    COUNT(DISTINCT wallet_address) as users_with_staked_nfts,
    COUNT(*) as total_staked_nfts,
    SUM(daily_reward) as expected_daily_rewards
FROM staked_nfts;

-- 9. Check for missing rewards (users with staked NFTs but no rewards today)
SELECT 
    'Missing Rewards Check' as check_type,
    sn.wallet_address,
    COUNT(sn.*) as staked_nfts,
    SUM(sn.daily_reward) as expected_daily_reward,
    COALESCE(sr.actual_reward, 0) as actual_reward_today
FROM staked_nfts sn
LEFT JOIN (
    SELECT 
        wallet_address,
        SUM(total_earned) as actual_reward
    FROM staking_rewards 
    WHERE reward_date = CURRENT_DATE
    GROUP BY wallet_address
) sr ON sr.wallet_address = sn.wallet_address
WHERE sr.actual_reward IS NULL OR sr.actual_reward = 0
GROUP BY sn.wallet_address, sr.actual_reward;

-- 10. Create/Update the cron job if needed
DO $$
BEGIN
    -- First try to delete existing job (if it exists)
    BEGIN
        PERFORM cron.unschedule('daily-staking-rewards');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'No existing cron job to remove';
    END;
    
    -- Create new cron job (runs daily at midnight UTC)
    PERFORM cron.schedule(
        'daily-staking-rewards',
        '0 0 * * *',  -- Every day at midnight UTC
        'SELECT generate_daily_staking_rewards();'
    );
    
    RAISE NOTICE '✅ Cron job created: daily-staking-rewards';
    RAISE NOTICE '📅 Schedule: Every day at midnight UTC';
    RAISE NOTICE '🔧 Command: SELECT generate_daily_staking_rewards();';
END $$;

-- 11. Verify the new cron job was created
SELECT 
    'New Cron Job Verification' as check_type,
    jobid,
    schedule,
    command,
    active,
    jobname
FROM cron.job 
WHERE jobname = 'daily-staking-rewards';

-- Summary and Next Steps
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 ============================================================================';
    RAISE NOTICE '🔍 CRON JOB TESTING COMPLETE';
    RAISE NOTICE '🔍 ============================================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 What to Check:';
    RAISE NOTICE '   1. Does generate_daily_staking_rewards() function exist?';
    RAISE NOTICE '   2. Are there active cron jobs for staking rewards?';
    RAISE NOTICE '   3. Do recent job executions show successful runs?';
    RAISE NOTICE '   4. Are rewards being generated for all staked users?';
    RAISE NOTICE '   5. Were rewards generated today?';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Manual Testing:';
    RAISE NOTICE '   - Run generate_daily_staking_rewards() manually';
    RAISE NOTICE '   - Check if new reward records are created';
    RAISE NOTICE '   - Verify rewards match daily_reward rates';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Troubleshooting:';
    RAISE NOTICE '   - If no cron jobs: Create them with this script';
    RAISE NOTICE '   - If function missing: Deploy reward generation function';
    RAISE NOTICE '   - If rewards not generated: Check function permissions';
    RAISE NOTICE '   - If partial generation: Check for database errors';
    RAISE NOTICE '';
END $$;
