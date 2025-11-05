-- =============================================================================
-- QUICK FIX: Generate Pending Rewards NOW
-- =============================================================================
-- Run this in Supabase SQL Editor to immediately generate your pending rewards
-- =============================================================================

-- ⚡ STEP 1: Manually generate rewards for all users
SELECT generate_daily_staking_rewards() as result;

-- 📊 STEP 2: Check your pending rewards (REPLACE WITH YOUR WALLET ADDRESS)
SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS_HERE') as your_summary;

-- ✅ STEP 3: Verify rewards in database (REPLACE WITH YOUR WALLET ADDRESS)
SELECT 
    wallet_address,
    reward_date,
    nft_earned_today,
    token_earned_today,
    nft_earned_today + token_earned_today as total_today,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = 'YOUR_WALLET_ADDRESS_HERE'
ORDER BY reward_date DESC;

-- 🔄 STEP 4: Setup automatic rewards (every 6 hours)
-- Remove old jobs
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid FROM cron.job WHERE jobname LIKE '%staking%' OR jobname LIKE '%reward%'
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
    END LOOP;
END $$;

-- Create new cron job
SELECT cron.schedule(
    'generate-staking-rewards-6h',
    '0 */6 * * *',
    $$SELECT generate_daily_staking_rewards();$$
);

-- Verify cron job
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'generate-staking-rewards-6h';

-- =============================================================================
-- ✅ DONE! Refresh your staking page - pending rewards should now show!
-- =============================================================================

-- 📝 NOTES:
-- • Rewards now auto-generate every 6 hours
-- • You can manually run: SELECT generate_daily_staking_rewards();
-- • Monitor cron: SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
