-- ============================================================================
-- FIX CHECK-IN ACHIEVEMENTS
-- ============================================================================
-- Problem: "Check-in Starter" (requires 2 days) completes after just 1 claim
-- Solution: Ensure achievements only complete when total_claims >= required_count
-- ============================================================================

-- First, check and fix the achievement definitions
UPDATE achievement_master
SET 
  required_count = 2,
  title = 'Check-in Starter',
  description = 'Check in for 2 days'
WHERE achievement_key = 'checkin_starter';

UPDATE achievement_master
SET 
  required_count = 10,
  title = 'Regular Visitor',
  description = 'Check in for 10 days'
WHERE achievement_key = 'checkin_regular';

UPDATE achievement_master
SET 
  required_count = 30,
  title = 'Dedicated User',
  description = 'Check in for 30 days'
WHERE achievement_key = 'checkin_dedicated';

-- ============================================================================
-- Verify the fix worked
-- ============================================================================
DO $$
DECLARE
  checkin_starter_def RECORD;
  checkin_regular_def RECORD;
  checkin_dedicated_def RECORD;
BEGIN
  -- Get achievement definitions
  SELECT * INTO checkin_starter_def FROM achievement_master WHERE achievement_key = 'checkin_starter';
  SELECT * INTO checkin_regular_def FROM achievement_master WHERE achievement_key = 'checkin_regular';
  SELECT * INTO checkin_dedicated_def FROM achievement_master WHERE achievement_key = 'checkin_dedicated';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ CHECK-IN ACHIEVEMENT FIX APPLIED';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Achievement Requirements:';
  RAISE NOTICE '1. Check-in Starter: % claims required', checkin_starter_def.required_count;
  RAISE NOTICE '2. Regular Visitor: % claims required', checkin_regular_def.required_count;
  RAISE NOTICE '3. Dedicated User: % claims required', checkin_dedicated_def.required_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Logic:';
  RAISE NOTICE '- Uses user_streaks.total_claims (not current_streak)';
  RAISE NOTICE '- Completes ONLY when total_claims >= required_count';
  RAISE NOTICE '- Check-in Starter: Needs EXACTLY 2 claims (not 1)';
  RAISE NOTICE '';
  RAISE NOTICE 'Expected Behavior:';
  RAISE NOTICE '✅ 1 claim = 1/2 Check-in Starter (in progress)';
  RAISE NOTICE '✅ 2 claims = Check-in Starter COMPLETED';
  RAISE NOTICE '✅ 10 claims = Regular Visitor COMPLETED';
  RAISE NOTICE '✅ 30 claims = Dedicated User COMPLETED';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- Optional: Reset incorrectly completed achievements
-- ============================================================================
-- Uncomment the following lines if you want to reset achievements
-- that were completed too early:

-- DELETE FROM user_achievements 
-- WHERE achievement_key = 'checkin_starter'
--   AND wallet_address IN (
--     SELECT us.wallet_address 
--     FROM user_streaks us 
--     WHERE us.total_claims < 2
--   );

-- RAISE NOTICE 'Removed incorrectly completed "Check-in Starter" achievements';

-- ============================================================================
-- Test with a sample wallet
-- ============================================================================
-- To test, run this query after the fix:
-- SELECT wallet_address, total_claims FROM user_streaks WHERE wallet_address = 'YOUR_WALLET';
-- Then check get_user_achievements('YOUR_WALLET') to see if progress is correct
