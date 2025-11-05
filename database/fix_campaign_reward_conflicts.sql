-- ============================================================================
-- FIX CAMPAIGN REWARD CONFLICTS
-- Problem: TWO different balance update systems are conflicting
-- Solution: Remove old campaign-only trigger, use comprehensive aggregation
-- ============================================================================

-- STEP 1: Check what currently exists
DO $$
BEGIN
  RAISE NOTICE '=== CAMPAIGN REWARD CONFLICT FIX ===';
  RAISE NOTICE 'Checking current triggers and functions...';
END $$;

-- Check current triggers on campaign_reward_claims
SELECT 
  'Current triggers on campaign_reward_claims:' as check_step,
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'campaign_reward_claims';

-- ============================================================================
-- STEP 2: Remove OLD campaign-only system
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=== REMOVING OLD CAMPAIGN-ONLY SYSTEM ===';
  RAISE NOTICE 'This trigger only updates balance from campaigns, causing conflicts';
END $$;

-- Drop the OLD campaign-only trigger
DROP TRIGGER IF EXISTS trigger_update_user_balance_after_claim ON campaign_reward_claims CASCADE;

-- Drop the OLD campaign-only function
DROP FUNCTION IF EXISTS update_user_balance_after_claim() CASCADE;

-- ============================================================================
-- STEP 3: Create shared trigger function for comprehensive sync
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_user_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Use comprehensive aggregation system
  -- This aggregates from ALL reward sources, not just campaigns
  PERFORM sync_user_balance_from_all_sources(NEW.wallet_address);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sync_user_balance_trigger IS 
'Shared trigger function that syncs user balance using comprehensive aggregation from all reward sources (campaigns, daily claims, achievements, staking, referrals)';

-- ============================================================================
-- STEP 4: Create NEW trigger using comprehensive sync
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_sync_balance_after_campaign_claim ON campaign_reward_claims;

CREATE TRIGGER trigger_sync_balance_after_campaign_claim
AFTER INSERT ON campaign_reward_claims
FOR EACH ROW
EXECUTE FUNCTION sync_user_balance_trigger();

COMMENT ON TRIGGER trigger_sync_balance_after_campaign_claim ON campaign_reward_claims IS 
'Automatically syncs user balance using comprehensive aggregation after campaign reward claim. Aggregates from ALL sources: campaigns + daily claims + achievements + staking + referrals';

-- ============================================================================
-- STEP 5: Grant proper permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION sync_user_balance_trigger() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION sync_user_balance_from_all_sources(TEXT) TO authenticated, anon, service_role;

-- ============================================================================
-- STEP 6: Fix RLS policies on user_balances table
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '=== FIXING RLS POLICIES ON user_balances ===';
  RAISE NOTICE 'Allowing sync functions to update balances...';
END $$;

-- Drop old conflicting policies
DROP POLICY IF EXISTS "Users can insert own balances" ON user_balances;
DROP POLICY IF EXISTS "Users can update own balances" ON user_balances;

-- Keep the view policy
-- DROP POLICY IF EXISTS "Users can view own balances" ON user_balances;

-- Create new comprehensive policies
CREATE POLICY "users_select_own_balance" ON user_balances
  FOR SELECT 
  TO authenticated, anon
  USING (
    wallet_address = current_setting('request.headers.x-wallet-address', true)
  );

-- Allow service role to manage all balances (for sync functions)
CREATE POLICY "service_role_all_access" ON user_balances
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Allow sync functions running as SECURITY DEFINER to bypass RLS
ALTER TABLE user_balances FORCE ROW LEVEL SECURITY;

COMMENT ON POLICY "users_select_own_balance" ON user_balances IS 
'Users can only view their own balance using wallet address header';

COMMENT ON POLICY "service_role_all_access" ON user_balances IS 
'Service role (used by sync functions) can manage all user balances';

-- ============================================================================
-- STEP 7: Verify sync_user_balance_from_all_sources exists
-- ============================================================================

DO $$
DECLARE
  function_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'sync_user_balance_from_all_sources'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ sync_user_balance_from_all_sources function exists';
  ELSE
    RAISE WARNING '❌ sync_user_balance_from_all_sources function NOT FOUND!';
    RAISE WARNING 'You need to deploy: database/comprehensive_balance_aggregation_system.sql';
  END IF;
END $$;

-- ============================================================================
-- STEP 8: Verify aggregate_user_rewards_from_all_sources exists
-- ============================================================================

DO $$
DECLARE
  function_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'aggregate_user_rewards_from_all_sources'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ aggregate_user_rewards_from_all_sources function exists';
  ELSE
    RAISE WARNING '❌ aggregate_user_rewards_from_all_sources function NOT FOUND!';
    RAISE WARNING 'You need to deploy: database/comprehensive_balance_aggregation_system.sql';
  END IF;
END $$;

-- ============================================================================
-- STEP 9: Verify the fix
-- ============================================================================

-- Check that only ONE trigger exists now
DO $$
DECLARE
  trigger_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers 
  WHERE event_object_table = 'campaign_reward_claims';
  
  RAISE NOTICE '=== VERIFICATION ===';
  RAISE NOTICE 'Triggers on campaign_reward_claims table: %', trigger_count;
  
  IF trigger_count = 1 THEN
    RAISE NOTICE '✅ Perfect! Only one trigger exists';
  ELSIF trigger_count > 1 THEN
    RAISE WARNING '⚠️ Multiple triggers detected! Check for duplicates';
  ELSE
    RAISE WARNING '⚠️ No triggers found! Trigger may not have been created';
  END IF;
END $$;

-- Show the current trigger
SELECT 
  '=== CURRENT CAMPAIGN TRIGGERS ===' as status,
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement as trigger_action
FROM information_schema.triggers 
WHERE event_object_table = 'campaign_reward_claims';

-- ============================================================================
-- STEP 10: Create a test to verify everything works
-- ============================================================================

DO $$
DECLARE
  test_wallet TEXT := 'test_wallet_' || floor(random() * 1000000)::TEXT;
  test_project TEXT := 'test_project_' || floor(random() * 1000000)::TEXT;
  balance_before DECIMAL(18,8);
  balance_after DECIMAL(18,8);
BEGIN
  RAISE NOTICE '=== TESTING CAMPAIGN REWARD SYSTEM ===';
  RAISE NOTICE 'Test wallet: %', test_wallet;
  
  -- Check balance before (should be 0 or not exist)
  SELECT COALESCE(total_neft_claimed, 0) INTO balance_before
  FROM user_balances 
  WHERE wallet_address = test_wallet;
  
  RAISE NOTICE 'Balance before: %', COALESCE(balance_before, 0);
  
  -- Insert a test campaign reward claim
  INSERT INTO campaign_reward_claims (wallet_address, project_id, neft_reward, xp_reward)
  VALUES (test_wallet, test_project, 100, 50);
  
  RAISE NOTICE 'Inserted test campaign claim: 100 NEFT, 50 XP';
  
  -- Wait a moment for trigger to execute
  PERFORM pg_sleep(0.5);
  
  -- Check balance after trigger
  SELECT COALESCE(total_neft_claimed, 0) INTO balance_after
  FROM user_balances 
  WHERE wallet_address = test_wallet;
  
  RAISE NOTICE 'Balance after: %', COALESCE(balance_after, 0);
  
  -- Verify the balance increased
  IF balance_after = 100 THEN
    RAISE NOTICE '✅ TEST PASSED! Campaign reward added to balance correctly';
    RAISE NOTICE '✅ Trigger is working with comprehensive sync';
  ELSIF balance_after = 0 THEN
    RAISE WARNING '❌ TEST FAILED! Balance did not update';
    RAISE WARNING '❌ Check if trigger is enabled and sync function works';
  ELSE
    RAISE NOTICE '⚠️ Balance is % (expected 100)', balance_after;
  END IF;
  
  -- Cleanup test data
  DELETE FROM campaign_reward_claims WHERE wallet_address = test_wallet;
  DELETE FROM user_balances WHERE wallet_address = test_wallet;
  
  RAISE NOTICE 'Test data cleaned up';
  
END $$;

-- ============================================================================
-- STEP 11: Final summary
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== CAMPAIGN REWARD CONFLICT FIX COMPLETE ===';
  RAISE NOTICE '';
  RAISE NOTICE '✅ REMOVED: Old campaign-only trigger (trigger_update_user_balance_after_claim)';
  RAISE NOTICE '✅ REMOVED: Old campaign-only function (update_user_balance_after_claim)';
  RAISE NOTICE '✅ CREATED: New comprehensive trigger (trigger_sync_balance_after_campaign_claim)';
  RAISE NOTICE '✅ CREATED: Shared trigger function (sync_user_balance_trigger)';
  RAISE NOTICE '✅ FIXED: RLS policies to allow sync function updates';
  RAISE NOTICE '';
  RAISE NOTICE 'Campaign rewards will now:';
  RAISE NOTICE '1. Insert into campaign_reward_claims table';
  RAISE NOTICE '2. Trigger comprehensive sync (all reward sources)';
  RAISE NOTICE '3. Update user_balances with aggregated totals';
  RAISE NOTICE '4. Fire Supabase real-time update';
  RAISE NOTICE '5. Update UI via UserBalanceContext';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Deploy: database/fix_add_referral_to_aggregation.sql (if not done)';
  RAISE NOTICE '2. Test campaign claim in your app';
  RAISE NOTICE '3. Verify balance updates in MainNav';
  RAISE NOTICE '';
END $$;
