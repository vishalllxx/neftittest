-- ============================================================================
-- FIX EXISTING USER DATA (Double Counted Claims)
-- ============================================================================
-- Problem: Some users have total_claims = 2 but only made 1 actual claim
-- Solution: Reset total_claims to match actual daily_claims count
-- ============================================================================

-- Update total_claims to match actual claim count
UPDATE user_streaks
SET total_claims = (
  SELECT COUNT(*)
  FROM daily_claims
  WHERE daily_claims.wallet_address = user_streaks.wallet_address
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ USER DATA FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Updated total_claims to match actual daily_claims records.';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Users who had total_claims = 2 with only 1 claim now show 1 claim.';
  RAISE NOTICE 'Achievements will now require the correct number of claims!';
  RAISE NOTICE ' ';
END $$;
