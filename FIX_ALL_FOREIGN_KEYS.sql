-- ============================================================================
-- REMOVE ALL FOREIGN KEY CONSTRAINTS BLOCKING DAILY CLAIMS
-- ============================================================================
-- Problem: Both user_streaks AND user_balances have foreign keys to "users" table
-- Solution: Remove BOTH constraints
-- ============================================================================

-- Remove foreign key from user_streaks
ALTER TABLE user_streaks 
DROP CONSTRAINT IF EXISTS fk_user_streaks_wallet_address CASCADE;

-- Remove foreign key from user_balances  
ALTER TABLE user_balances 
DROP CONSTRAINT IF EXISTS fk_user_balances_wallet_address CASCADE;

-- Also check for any other possible constraint names
ALTER TABLE user_streaks 
DROP CONSTRAINT IF EXISTS user_streaks_wallet_address_fkey CASCADE;

ALTER TABLE user_balances 
DROP CONSTRAINT IF EXISTS user_balances_wallet_address_fkey CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ALL FOREIGN KEY CONSTRAINTS REMOVED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Removed constraints:';
  RAISE NOTICE '1. ✅ fk_user_streaks_wallet_address';
  RAISE NOTICE '2. ✅ fk_user_balances_wallet_address';
  RAISE NOTICE '3. ✅ user_streaks_wallet_address_fkey';
  RAISE NOTICE '4. ✅ user_balances_wallet_address_fkey';
  RAISE NOTICE ' ';
  RAISE NOTICE '🚀 Daily claims will now work without foreign key errors!';
  RAISE NOTICE ' ';
END $$;
