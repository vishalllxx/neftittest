-- ================================================================ =============
-- FIX 02: REWARD GENERATION - SINGLE CRON JOB VERSION
-- =============================================================================
-- Purpose: Same as FIX_02 but with ONLY ONE cron job (choose your preference)
-- Deploy: Use THIS instead of FIX_02_REWARD_GENERATION.sql if you want single cron
-- Status: ALTERNATIVE VERSION

-- Note: This file contains the same reward logic as FIX_02_REWARD_GENERATION.sql
-- The ONLY difference is the cron job configuration at the end

-- =============================================================================
-- (Include all the same functions from FIX_02 here)
-- stake_tokens(), generate_daily_staking_rewards(), etc.
-- =============================================================================

-- [... All previous functions from FIX_02 remain the same ...]
-- [... Including stake_tokens, generate_daily_staking_rewards, etc. ...]
-- [... Refer to FIX_02_REWARD_GENERATION.sql for the complete functions ...]

-- =============================================================================
-- PART 4: SETUP SUPABASE CRON JOB - CHOOSE YOUR FREQUENCY
-- =============================================================================

-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove any existing staking reward cron jobs
DO $$
DECLARE
    job_record RECORD;
BEGIN
    FOR job_record IN 
        SELECT jobid FROM cron.job WHERE jobname LIKE '%staking-reward%'
    LOOP
        PERFORM cron.unschedule(job_record.jobid);
        RAISE NOTICE 'Removed existing cron job: %', job_record.jobid;
    END LOOP;
END $$;

-- =============================================================================
-- OPTION 1: Every 24 Hours (Daily at Midnight UTC)
-- =============================================================================
-- Uncomment this if you want rewards to update ONCE per day

/*
SELECT cron.schedule(
    'generate-staking-rewards-daily',
    '0 0 * * *',  -- Every day at 00:00 UTC (midnight)
    $$SELECT generate_daily_staking_rewards();$$
);

DO $$
BEGIN
    RAISE NOTICE '✅ Cron Job: Daily at midnight UTC (every 24 hours)';
END $$;
*/

-- =============================================================================
-- OPTION 2: Every 6 Hours (Recommended for Better UX)
-- =============================================================================
-- Uncomment this if you want rewards to update 4× per day
-- Runs at: 00:00, 06:00, 12:00, 18:00 UTC

SELECT cron.schedule(
    'generate-staking-rewards-6h',
    '0 */6 * * *',  -- Every 6 hours
    $$SELECT generate_daily_staking_rewards();$$
);

DO $$
BEGIN
    RAISE NOTICE '✅ Cron Job: Every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)';
END $$;

-- =============================================================================
-- OPTION 3: Every Hour (For High-Activity Platforms)
-- =============================================================================
-- Uncomment this if you want very frequent updates (high DB load)

/*
SELECT cron.schedule(
    'generate-staking-rewards-hourly',
    '0 * * * *',  -- Every hour at minute 0
    $$SELECT generate_daily_staking_rewards();$$
);

DO $$
BEGIN
    RAISE NOTICE '✅ Cron Job: Every hour';
END $$;
*/

-- =============================================================================
-- OPTION 4: Every 12 Hours (Balanced Approach)
-- =============================================================================
-- Uncomment this if you want middle-ground between daily and 6-hourly

/*
SELECT cron.schedule(
    'generate-staking-rewards-12h',
    '0 */12 * * *',  -- Every 12 hours (00:00 and 12:00 UTC)
    $$SELECT generate_daily_staking_rewards();$$
);

DO $$
BEGIN
    RAISE NOTICE '✅ Cron Job: Every 12 hours (00:00, 12:00 UTC)';
END $$;
*/

-- =============================================================================
-- VERIFICATION: View Scheduled Cron Jobs
-- =============================================================================

DO $$
DECLARE
    job_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO job_count FROM cron.job WHERE jobname LIKE '%staking-reward%';
    
    RAISE NOTICE '';
    RAISE NOTICE '=== CRON JOB CONFIGURATION ===';
    RAISE NOTICE '';
    RAISE NOTICE 'Active staking reward cron jobs: %', job_count;
    RAISE NOTICE '';
    RAISE NOTICE 'To view cron jobs:';
    RAISE NOTICE '  SELECT * FROM cron.job WHERE jobname LIKE ''%%staking-reward%%'';';
    RAISE NOTICE '';
    RAISE NOTICE 'To view cron job execution history:';
    RAISE NOTICE '  SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- MANUAL TRIGGER (For Testing)
-- =============================================================================

-- You can always trigger reward generation manually:
-- SELECT generate_daily_staking_rewards();
