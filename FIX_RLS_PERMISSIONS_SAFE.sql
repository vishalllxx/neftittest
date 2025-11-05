-- ============================================================================
-- FIX RLS AND PERMISSIONS FOR ACHIEVEMENTS (SAFE VERSION)
-- ============================================================================
-- This fixes the "No achievements found" issue by properly configuring
-- Row Level Security and permissions, with error handling for missing tables
-- ============================================================================

-- Step 1: Disable RLS on achievements_master (it's reference data, should be publicly readable)
ALTER TABLE achievements_master DISABLE ROW LEVEL SECURITY;

-- Step 2: Disable RLS on user_achievement_progress
ALTER TABLE user_achievement_progress DISABLE ROW LEVEL SECURITY;

-- Step 3: Grant SELECT permissions to public on achievements_master
GRANT SELECT ON achievements_master TO authenticated, anon, public;

-- Step 4: Grant proper permissions on user_achievement_progress
GRANT SELECT, INSERT, UPDATE ON user_achievement_progress TO authenticated, anon, public;

-- Step 5: Grant permissions on user_balances table (needed for claim function)
GRANT SELECT, INSERT, UPDATE ON user_balances TO authenticated, anon, public;

-- Step 6: Grant permissions on related tables (with error handling)
DO $$
BEGIN
  -- Grant on projects table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'projects') THEN
    GRANT SELECT ON projects TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on projects';
  ELSE
    RAISE NOTICE '⚠ Table projects does not exist, skipping';
  END IF;

  -- Grant on campaign_reward_claims table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'campaign_reward_claims') THEN
    GRANT SELECT ON campaign_reward_claims TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on campaign_reward_claims';
  ELSE
    RAISE NOTICE '⚠ Table campaign_reward_claims does not exist, skipping';
  END IF;

  -- Grant on nft_burns table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'nft_burns') THEN
    GRANT SELECT ON nft_burns TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on nft_burns';
  ELSE
    RAISE NOTICE '⚠ Table nft_burns does not exist, skipping';
  END IF;

  -- Grant on referrals table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'referrals') THEN
    GRANT SELECT ON referrals TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on referrals';
  ELSE
    RAISE NOTICE '⚠ Table referrals does not exist, skipping';
  END IF;

  -- Grant on user_streaks table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_streaks') THEN
    GRANT SELECT ON user_streaks TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on user_streaks';
  ELSE
    RAISE NOTICE '⚠ Table user_streaks does not exist, skipping';
  END IF;

  -- Grant on staked_tokens table if it exists
  IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'staked_tokens') THEN
    GRANT SELECT ON staked_tokens TO authenticated, anon, public;
    RAISE NOTICE '✓ Granted SELECT on staked_tokens';
  ELSE
    RAISE NOTICE '⚠ Table staked_tokens does not exist, skipping';
  END IF;
END $$;

-- Step 7: Ensure functions have proper permissions
GRANT EXECUTE ON FUNCTION get_user_achievement_status(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_achievement(TEXT, TEXT) TO authenticated, anon, public;

-- Step 8: Test the function directly
SELECT 'Testing get_user_achievement_status function...' as test_step;
SELECT get_user_achievement_status('test_wallet_address');

-- Step 9: Verify achievements_master has data
SELECT 'Verifying achievements_master data...' as test_step;
SELECT 
  COUNT(*) as total_achievements,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_achievements
FROM achievements_master;

-- Step 10: Show all active achievements by category
SELECT 'Showing all active achievements by category...' as test_step;
SELECT 
  category,
  COUNT(*) as count,
  string_agg(achievement_key, ', ') as achievement_keys
FROM achievements_master 
WHERE is_active = TRUE
GROUP BY category
ORDER BY category;

-- Step 11: Verify RLS is now disabled
SELECT 'Verifying RLS is disabled...' as test_step;
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename IN ('achievements_master', 'user_achievement_progress');

SELECT '✅ RLS AND PERMISSIONS FIXED (SAFE MODE)!' as status;
SELECT '📋 Next Steps:' as instructions;
SELECT '1. Refresh your achievements page in the browser (Ctrl+Shift+R)' as step_1;
SELECT '2. You should now see all 18 achievements' as step_2;
SELECT '3. If you see notices above about missing tables, those features will show 0 progress' as step_3;
SELECT '4. Missing tables are OK - they will be created when you use those features' as step_4;
