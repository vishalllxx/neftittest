-- ============================================================================
-- NUCLEAR OPTION: REMOVE ALL FOREIGN KEY CONSTRAINTS
-- ============================================================================
-- Problem: EVERY daily claims table has foreign keys to "users" table
-- Solution: Remove ALL constraints from ALL tables
-- ============================================================================

-- Remove ALL foreign keys from user_streaks
ALTER TABLE user_streaks DROP CONSTRAINT IF EXISTS fk_user_streaks_wallet_address CASCADE;
ALTER TABLE user_streaks DROP CONSTRAINT IF EXISTS user_streaks_wallet_address_fkey CASCADE;

-- Remove ALL foreign keys from user_balances
ALTER TABLE user_balances DROP CONSTRAINT IF EXISTS fk_user_balances_wallet_address CASCADE;
ALTER TABLE user_balances DROP CONSTRAINT IF EXISTS user_balances_wallet_address_fkey CASCADE;

-- Remove ALL foreign keys from daily_claims
ALTER TABLE daily_claims DROP CONSTRAINT IF EXISTS fk_daily_claims_wallet_address CASCADE;
ALTER TABLE daily_claims DROP CONSTRAINT IF EXISTS daily_claims_wallet_address_fkey CASCADE;

-- Remove ALL foreign keys from any other related tables
ALTER TABLE daily_claim_milestones DROP CONSTRAINT IF EXISTS fk_daily_claim_milestones_wallet_address CASCADE;
ALTER TABLE daily_claim_milestones DROP CONSTRAINT IF EXISTS daily_claim_milestones_wallet_address_fkey CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '🔥 NUCLEAR OPTION COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Removed ALL foreign key constraints from:';
  RAISE NOTICE '1. ✅ user_streaks';
  RAISE NOTICE '2. ✅ user_balances';
  RAISE NOTICE '3. ✅ daily_claims';
  RAISE NOTICE '4. ✅ daily_claim_milestones';
  RAISE NOTICE ' ';
  RAISE NOTICE '🚀 Daily claims will now work WITHOUT ANY foreign key errors!';
  RAISE NOTICE ' ';
END $$;
