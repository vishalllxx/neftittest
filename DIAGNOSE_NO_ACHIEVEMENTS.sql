-- ============================================================================
-- DIAGNOSE WHY NO ACHIEVEMENTS ARE SHOWING
-- ============================================================================
-- Run this script to identify the exact issue
-- ============================================================================

-- Test 1: Check if achievements_master table has data
SELECT '=== TEST 1: Check achievements_master data ===' as test;
SELECT 
  COUNT(*) as total_records,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_records
FROM achievements_master;

-- Test 2: Show all achievements
SELECT '=== TEST 2: List all achievements ===' as test;
SELECT 
  achievement_key,
  title,
  category,
  is_active
FROM achievements_master
ORDER BY sort_order;

-- Test 3: Check RLS policies
SELECT '=== TEST 3: Check RLS status ===' as test;
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('achievements_master', 'user_achievement_progress');

-- Test 4: Check function exists
SELECT '=== TEST 4: Check function exists ===' as test;
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_name = 'get_user_achievement_status';

-- Test 5: Test function with dummy wallet
SELECT '=== TEST 5: Test function with dummy wallet ===' as test;
SELECT get_user_achievement_status('0x0000000000000000000000000000000000000000');

-- Test 6: Check table permissions
SELECT '=== TEST 6: Check table permissions ===' as test;
SELECT 
  grantee,
  table_name,
  privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'achievements_master';

-- Test 7: Try to manually query achievements_master
SELECT '=== TEST 7: Manual query of achievements_master ===' as test;
SELECT 
  achievement_key,
  title,
  category,
  neft_reward,
  xp_reward,
  required_count
FROM achievements_master
WHERE is_active = true
LIMIT 5;

-- Test 8: Check for errors in function
SELECT '=== TEST 8: Check function definition ===' as test;
SELECT 
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_name = 'get_user_achievement_status';

-- Test 9: Check if function returns JSON or error
SELECT '=== TEST 9: Parse function output ===' as test;
WITH function_result AS (
  SELECT get_user_achievement_status('test_wallet') as result
)
SELECT 
  result,
  pg_typeof(result) as result_type,
  CASE 
    WHEN result::text LIKE '%error%' THEN 'ERROR FOUND'
    WHEN result::text = '[]' THEN 'EMPTY ARRAY'
    WHEN result::text LIKE '[{%' THEN 'VALID JSON ARRAY'
    ELSE 'UNKNOWN FORMAT'
  END as status
FROM function_result;

SELECT '✅ DIAGNOSIS COMPLETE' as status;
SELECT 'Review the results above to identify the issue' as instruction;
