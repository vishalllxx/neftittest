-- ============================================================================
-- DEBUG REWARD CALCULATION - Check for Double Addition Issue
-- ============================================================================
-- This script helps identify if rewards are being added correctly or doubled
-- ============================================================================

-- Test the calculate_daily_reward function for different streak days
DO $$
DECLARE
  day1_reward RECORD;
  day2_reward RECORD;
  day3_reward RECORD;
BEGIN
  -- Test Day 1 rewards
  SELECT * INTO day1_reward FROM calculate_daily_reward(1, 'test_wallet');
  RAISE NOTICE 'Day 1 Rewards: NEFT=% (base=%, bonus=%), XP=% (base=%, bonus=%)', 
    (day1_reward.base_neft + day1_reward.bonus_neft),
    day1_reward.base_neft, day1_reward.bonus_neft,
    (day1_reward.base_xp + day1_reward.bonus_xp),
    day1_reward.base_xp, day1_reward.bonus_xp;

  -- Test Day 2 rewards
  SELECT * INTO day2_reward FROM calculate_daily_reward(2, 'test_wallet');
  RAISE NOTICE 'Day 2 Rewards: NEFT=% (base=%, bonus=%), XP=% (base=%, bonus=%)', 
    (day2_reward.base_neft + day2_reward.bonus_neft),
    day2_reward.base_neft, day2_reward.bonus_neft,
    (day2_reward.base_xp + day2_reward.bonus_xp),
    day2_reward.base_xp, day2_reward.bonus_xp;

  -- Test Day 3 rewards
  SELECT * INTO day3_reward FROM calculate_daily_reward(3, 'test_wallet');
  RAISE NOTICE 'Day 3 Rewards: NEFT=% (base=%, bonus=%), XP=% (base=%, bonus=%)', 
    (day3_reward.base_neft + day3_reward.bonus_neft),
    day3_reward.base_neft, day3_reward.bonus_neft,
    (day3_reward.base_xp + day3_reward.bonus_xp),
    day3_reward.base_xp, day3_reward.bonus_xp;
END;
$$;

-- Check if there are any triggers on user_streaks or user_balances that might duplicate rewards
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers 
WHERE event_object_table IN ('user_streaks', 'user_balances', 'daily_claims')
ORDER BY event_object_table, trigger_name;

-- Check for any functions that might be called by triggers
SELECT 
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines 
WHERE routine_name LIKE '%sync%' 
   OR routine_name LIKE '%balance%'
   OR routine_name LIKE '%streak%'
   OR routine_name LIKE '%daily%'
ORDER BY routine_name;

-- Sample query to check actual user data (replace with your wallet)
-- This will show you the current state of both tables
SELECT 'user_streaks' as table_name, 
       wallet_address, 
       current_streak,
       total_neft_earned, 
       total_xp_earned,
       last_claim_date
FROM user_streaks 
WHERE wallet_address = 'social:google:117810411522178554147'

UNION ALL

SELECT 'user_balances' as table_name,
       wallet_address,
       0 as current_streak,
       total_neft_claimed as total_neft_earned,
       total_xp_earned,
       last_updated::date as last_claim_date
FROM user_balances 
WHERE wallet_address = 'social:google:117810411522178554147';

-- Check daily_claims history
SELECT 
  claim_date,
  streak_count,
  base_neft_reward,
  bonus_neft_reward,
  base_xp_reward,
  bonus_xp_reward,
  (base_neft_reward + bonus_neft_reward) as total_neft,
  (base_xp_reward + bonus_xp_reward) as total_xp
FROM daily_claims 
WHERE wallet_address = 'social:google:117810411522178554147'
ORDER BY claim_date DESC;

SELECT 'DEBUG_REWARD_CALCULATION completed - Check the output above for double-addition issues' as status;
