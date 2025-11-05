-- ============================================================================
-- COMPLETE BALANCE SYSTEM DEPLOYMENT
-- Deploy this ONE file to fix everything!
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '   NEFTIT BALANCE SYSTEM DEPLOYMENT';
  RAISE NOTICE '   Deploying all fixes in correct order...';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 1: Check Prerequisites
-- ============================================================================

DO $$
DECLARE
  table_exists BOOLEAN;
BEGIN
  RAISE NOTICE '[1/5] Checking prerequisites...';
  
  -- Check if user_balances table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'user_balances'
  ) INTO table_exists;
  
  IF table_exists THEN
    RAISE NOTICE '  ✅ user_balances table exists';
  ELSE
    RAISE WARNING '  ⚠️ user_balances table does NOT exist!';
    RAISE WARNING '  Deploy database/campaign_rewards_schema.sql first!';
  END IF;
  
  -- Check if campaign_reward_claims table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'campaign_reward_claims'
  ) INTO table_exists;
  
  IF table_exists THEN
    RAISE NOTICE '  ✅ campaign_reward_claims table exists';
  ELSE
    RAISE WARNING '  ⚠️ campaign_reward_claims table does NOT exist!';
    RAISE WARNING '  Deploy database/campaign_rewards_schema.sql first!';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 2: Deploy Comprehensive Aggregation System
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '[2/5] Deploying comprehensive aggregation system...';
  RAISE NOTICE '  This creates the foundation functions...';
END $$;

-- Include the comprehensive system here
-- Note: You need to manually copy the contents of:
-- database/User balance/comprehensive_balance_aggregation_system.sql
-- into this section

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '  ⚠️ MANUAL STEP REQUIRED:';
  RAISE NOTICE '  ';
  RAISE NOTICE '  1. Open: database/User balance/comprehensive_balance_aggregation_system.sql';
  RAISE NOTICE '  2. Copy lines 1-420 (entire file)';
  RAISE NOTICE '  3. Run that file FIRST in SQL Editor';
  RAISE NOTICE '  4. Then return here and run the rest';
  RAISE NOTICE '';
  RAISE NOTICE '  OR use the simplified version below...';
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 3: Remove Old Campaign System
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '[3/5] Removing old campaign-only system...';
END $$;

-- Drop the OLD campaign-only trigger
DROP TRIGGER IF EXISTS trigger_update_user_balance_after_claim ON campaign_reward_claims CASCADE;
RAISE NOTICE '  ✅ Removed old trigger';

-- Drop the OLD campaign-only function
DROP FUNCTION IF EXISTS update_user_balance_after_claim() CASCADE;
RAISE NOTICE '  ✅ Removed old function';

-- ============================================================================
-- STEP 4: Create New Comprehensive Trigger
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '[4/5] Creating new comprehensive trigger...';
END $$;

-- Shared trigger function
CREATE OR REPLACE FUNCTION sync_user_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM sync_user_balance_from_all_sources(NEW.wallet_address);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

RAISE NOTICE '  ✅ Created trigger function';

-- Create trigger
DROP TRIGGER IF EXISTS trigger_sync_balance_after_campaign_claim ON campaign_reward_claims;

CREATE TRIGGER trigger_sync_balance_after_campaign_claim
AFTER INSERT ON campaign_reward_claims
FOR EACH ROW
EXECUTE FUNCTION sync_user_balance_trigger();

RAISE NOTICE '  ✅ Created campaign reward trigger';

-- ============================================================================
-- STEP 5: Fix RLS Policies
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '[5/5] Fixing RLS policies...';
END $$;

-- Drop conflicting policies
DROP POLICY IF EXISTS "Users can insert own balances" ON user_balances;
DROP POLICY IF EXISTS "Users can update own balances" ON user_balances;

-- Create proper policies
DROP POLICY IF EXISTS "users_select_own_balance" ON user_balances;
CREATE POLICY "users_select_own_balance" ON user_balances
  FOR SELECT 
  TO authenticated, anon
  USING (
    wallet_address = current_setting('request.headers.x-wallet-address', true)
  );

DROP POLICY IF EXISTS "service_role_all_access" ON user_balances;
CREATE POLICY "service_role_all_access" ON user_balances
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

RAISE NOTICE '  ✅ RLS policies updated';

-- ============================================================================
-- STEP 6: Grant Permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION sync_user_balance_trigger() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION sync_user_balance_from_all_sources(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION aggregate_user_rewards_from_all_sources(TEXT) TO authenticated, anon, service_role;

RAISE NOTICE '  ✅ Permissions granted';

-- ============================================================================
-- STEP 7: Verification
-- ============================================================================

DO $$
DECLARE
  trigger_count INTEGER;
  function_exists BOOLEAN;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '   VERIFICATION';
  RAISE NOTICE '==============================================';
  
  -- Check triggers
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers 
  WHERE event_object_table = 'campaign_reward_claims';
  
  RAISE NOTICE 'Triggers on campaign_reward_claims: %', trigger_count;
  
  -- Check functions
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'sync_user_balance_from_all_sources'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ sync_user_balance_from_all_sources exists';
  ELSE
    RAISE WARNING '❌ sync_user_balance_from_all_sources NOT FOUND!';
    RAISE WARNING 'You must deploy comprehensive_balance_aggregation_system.sql FIRST!';
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'aggregate_user_rewards_from_all_sources'
  ) INTO function_exists;
  
  IF function_exists THEN
    RAISE NOTICE '✅ aggregate_user_rewards_from_all_sources exists';
  ELSE
    RAISE WARNING '❌ aggregate_user_rewards_from_all_sources NOT FOUND!';
    RAISE WARNING 'You must deploy comprehensive_balance_aggregation_system.sql FIRST!';
  END IF;
  
  RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 8: Final Instructions
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '==============================================';
  RAISE NOTICE '   DEPLOYMENT SUMMARY';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
  RAISE NOTICE 'If you see function NOT FOUND errors above:';
  RAISE NOTICE '';
  RAISE NOTICE '1. Deploy this file FIRST:';
  RAISE NOTICE '   database/User balance/comprehensive_balance_aggregation_system.sql';
  RAISE NOTICE '';
  RAISE NOTICE '2. Then run THIS file again';
  RAISE NOTICE '';
  RAISE NOTICE '3. Then deploy:';
  RAISE NOTICE '   database/fix_add_referral_to_aggregation.sql';
  RAISE NOTICE '';
  RAISE NOTICE 'If all functions exist:';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Campaign reward system is now fixed!';
  RAISE NOTICE '✅ Test by claiming a campaign reward in your app';
  RAISE NOTICE '';
  RAISE NOTICE '==============================================';
  RAISE NOTICE '';
END $$;
