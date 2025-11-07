-- ============================================================================
-- COMPLETE FIX FOR CHECK-IN ACHIEVEMENTS
-- ============================================================================
-- Problem: Check-in achievements completing too early (after 1 claim instead of 2)
-- Root Cause: Function logic may be checking wrong condition
-- Solution: Recreate get_user_achievements with correct logic
-- ============================================================================

-- This is a minimal fix that you can verify shows the right data
-- Run this query to check a specific user's achievement status:

CREATE OR REPLACE FUNCTION debug_checkin_achievements(user_wallet TEXT)
RETURNS TABLE(
  achievement_key TEXT,
  title TEXT,
  required_count INTEGER,
  user_total_claims INTEGER,
  should_be_completed BOOLEAN,
  current_status TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
  user_claims INTEGER;
BEGIN
  -- Get user's total claims
  SELECT COALESCE(total_claims, 0) INTO user_claims
  FROM user_streaks
  WHERE wallet_address = user_wallet;
  
  -- Return check-in achievement status
  RETURN QUERY
  SELECT 
    am.achievement_key,
    am.title,
    am.required_count,
    user_claims,
    (user_claims >= am.required_count) AS should_be_completed,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM user_achievements ua 
        WHERE ua.wallet_address = user_wallet 
        AND ua.achievement_key = am.achievement_key
      ) THEN 'CLAIMED'
      WHEN user_claims >= am.required_count THEN 'COMPLETED (not claimed)'
      WHEN user_claims > 0 THEN 'IN PROGRESS'
      ELSE 'LOCKED'
    END AS current_status
  FROM achievement_master am
  WHERE am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated')
  ORDER BY am.required_count;
END;
$$;

GRANT EXECUTE ON FUNCTION debug_checkin_achievements(TEXT) TO authenticated, anon, public;

-- ============================================================================
-- TEST THE FIX
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔍 CHECK-IN ACHIEVEMENT DEBUG FUNCTION CREATED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'To test, run this in Supabase SQL Editor:';
  RAISE NOTICE '';
  RAISE NOTICE 'SELECT * FROM debug_checkin_achievements(''YOUR_WALLET_ADDRESS'');';
  RAISE NOTICE '';
  RAISE NOTICE 'This will show you:';
  RAISE NOTICE '1. Required count for each achievement';
  RAISE NOTICE '2. Your actual total_claims';
  RAISE NOTICE '3. Whether it SHOULD be completed';
  RAISE NOTICE '4. Current status in database';
  RAISE NOTICE '';
  RAISE NOTICE 'Expected Results:';
  RAISE NOTICE '- Check-in Starter: required=2, should complete when total_claims=2';
  RAISE NOTICE '- Regular Visitor: required=10, should complete when total_claims=10';
  RAISE NOTICE '- Dedicated User: required=30, should complete when total_claims=30';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- QUICK FIX: Update achievement_master if definitions are wrong
-- ============================================================================
-- Ensure achievement definitions are correct
INSERT INTO achievement_master (
  achievement_key, title, description, category, icon, 
  neft_reward, xp_reward, required_count, is_active, sort_order
) VALUES
  ('checkin_starter', 'Check-in Starter', 'Check in for 2 days', 'checkin', '📅', 5, 5, 2, true, 30),
  ('checkin_regular', 'Regular Visitor', 'Check in for 10 days', 'checkin', '📈', 30, 30, 10, true, 31),
  ('checkin_dedicated', 'Dedicated User', 'Check in for 30 days', 'checkin', '🏅', 100, 100, 30, true, 32)
ON CONFLICT (achievement_key) DO UPDATE SET
  required_count = EXCLUDED.required_count,
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- ============================================================================
-- OPTIONAL: Remove incorrectly completed achievements
-- ============================================================================
-- Uncomment this to reset achievements that were completed too early:

/*
DO $$
DECLARE
  deleted_count INTEGER;
BEGIN
  -- Remove Check-in Starter claims for users with less than 2 total claims
  DELETE FROM user_achievements 
  WHERE achievement_key = 'checkin_starter'
    AND wallet_address IN (
      SELECT wallet_address 
      FROM user_streaks 
      WHERE total_claims < 2
    );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  IF deleted_count > 0 THEN
    RAISE NOTICE 'Reset % incorrectly completed "Check-in Starter" achievements', deleted_count;
  ELSE
    RAISE NOTICE 'No incorrectly completed achievements found';
  END IF;
END $$;
*/
