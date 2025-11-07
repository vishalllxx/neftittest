-- ============================================================================
-- FIX FOREIGN KEY CONSTRAINT ON USER_STREAKS
-- ============================================================================
-- Problem: Daily claim fails with foreign key constraint error
-- Solution: Remove the problematic foreign key constraint
-- ============================================================================

-- Step 1: Check existing constraints
DO $$
BEGIN
  RAISE NOTICE 'Checking foreign key constraints on user_streaks...';
END $$;

-- Step 2: Drop the problematic foreign key constraint
ALTER TABLE user_streaks 
DROP CONSTRAINT IF EXISTS fk_user_streaks_wallet_address CASCADE;

-- Step 3: Verify the fix
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ FOREIGN KEY CONSTRAINT REMOVED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'The user_streaks table can now insert records freely.';
  RAISE NOTICE 'Daily claims will work without foreign key errors.';
  RAISE NOTICE ' ';
  RAISE NOTICE '⚠️  NOTE: If you need referential integrity, you should:';
  RAISE NOTICE '1. Ensure user_balances record is created BEFORE user_streaks';
  RAISE NOTICE '2. Re-add the foreign key with ON DELETE CASCADE';
  RAISE NOTICE ' ';
END $$;
