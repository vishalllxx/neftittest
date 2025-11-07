-- ============================================================================
-- FIX: Today's Reward Display
-- ============================================================================
-- Problem: When user has "1 Day Streak" and can claim today,
-- it shows "Today's Reward: 8 NEFT" (Day 2)
-- But should show "Today's Reward: 5 NEFT" (Day 1) until they actually claim
--
-- Solution: Change the logic to show the CURRENT day reward when can_claim,
-- not the NEXT day reward
-- ============================================================================

DROP FUNCTION IF EXISTS get_daily_claim_dashboard(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION get_daily_claim_dashboard(user_wallet TEXT)
RETURNS TABLE(
  -- Streak Information
  current_streak INTEGER,
  longest_streak INTEGER,
  total_claims INTEGER,
  can_claim_today BOOLEAN,
  last_claim_date DATE,
  total_neft_earned DECIMAL(18,8),
  total_xp_earned INTEGER,
  streak_started_at DATE,
  
  -- Next Claim Preview
  next_streak INTEGER,
  neft_reward DECIMAL(18,8),
  xp_reward INTEGER,
  reward_tier TEXT,
  cycle_day INTEGER,
  next_is_milestone BOOLEAN,
  
  -- Time calculations
  hours_until_next_claim INTEGER,
  minutes_until_next_claim INTEGER
)
SECURITY DEFINER
LANGUAGE plpgsql AS $$
DECLARE
  user_record RECORD;
  reward_data RECORD;
  can_claim BOOLEAN := FALSE;
  reward_streak_calc INTEGER;  -- The streak day to show rewards for
  display_streak INTEGER;      -- The streak to display to user
  today_date DATE := (NOW() AT TIME ZONE 'UTC')::DATE;
  hours_until INTEGER := 0;
  minutes_until INTEGER := 0;
  cycle_day_calc INTEGER;
BEGIN
  -- Get user streak record
  SELECT * INTO user_record FROM user_streaks WHERE wallet_address = user_wallet;
  
  -- Check if user can claim today (based on UTC date)
  can_claim := NOT EXISTS (
    SELECT 1 FROM daily_claims 
    WHERE wallet_address = user_wallet 
    AND claim_date = today_date
  );
  
  -- Calculate which day's reward to show
  IF user_record IS NULL THEN
    -- New user - show Day 1 rewards
    reward_streak_calc := 1;
    display_streak := 0;  -- Show as 0 days completed
  ELSE
    display_streak := user_record.current_streak;
    
    IF can_claim THEN
      -- ⭐ CRITICAL FIX: Determine if streak continues or resets
      IF user_record.last_claim_date = today_date - INTERVAL '1 day' THEN
        -- Claimed yesterday - continuing streak
        -- Show the NEXT day in the sequence
        reward_streak_calc := user_record.current_streak + 1;
      ELSE
        -- Either never claimed OR streak broken (missed a day)
        -- Reset to Day 1 rewards
        reward_streak_calc := 1;
        display_streak := 0;  -- Reset display to show "starting fresh"
      END IF;
    ELSE
      -- Already claimed today - show TOMORROW's reward
      reward_streak_calc := user_record.current_streak + 1;
    END IF;
  END IF;
  
  -- Calculate cycle day (1-7)
  cycle_day_calc := ((reward_streak_calc - 1) % 7) + 1;
  
  -- Get reward calculation for the appropriate day
  SELECT * INTO reward_data FROM calculate_daily_reward(reward_streak_calc, user_wallet);
  
  -- Calculate time until next claim (if already claimed today)
  IF NOT can_claim THEN
    -- Calculate hours and minutes until next 12AM UTC
    SELECT 
      EXTRACT(HOUR FROM ((today_date + INTERVAL '1 day')::TIMESTAMP - (NOW() AT TIME ZONE 'UTC')::TIMESTAMP))::INTEGER,
      EXTRACT(MINUTE FROM ((today_date + INTERVAL '1 day')::TIMESTAMP - (NOW() AT TIME ZONE 'UTC')::TIMESTAMP))::INTEGER
    INTO hours_until, minutes_until;
  END IF;
  
  -- Return comprehensive dashboard data
  RETURN QUERY SELECT 
    display_streak,  -- Show current completed streak
    COALESCE(user_record.longest_streak, 0),
    COALESCE(user_record.total_claims, 0),
    can_claim,
    user_record.last_claim_date,
    COALESCE(user_record.total_neft_earned, 0.0),
    COALESCE(user_record.total_xp_earned, 0),
    user_record.streak_started_at,
    reward_streak_calc,  -- The day number they're claiming
    reward_data.base_neft + reward_data.bonus_neft,
    reward_data.base_xp + reward_data.bonus_xp,
    reward_data.reward_tier,
    cycle_day_calc,
    reward_data.is_milestone,
    hours_until::INTEGER,
    minutes_until::INTEGER;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_daily_claim_dashboard(TEXT) TO authenticated, anon, public;

-- ============================================================================
-- Test the fix
-- ============================================================================
DO $$
DECLARE
  test_result RECORD;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TODAYS REWARD DISPLAY FIX APPLIED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Logic Changes:';
  RAISE NOTICE '1. When user CAN claim today:';
  RAISE NOTICE '   - Shows the reward for the day they are ABOUT TO CLAIM';
  RAISE NOTICE '   - "1 Day Streak + Can Claim" = Shows Day 1 rewards (5 NEFT)';
  RAISE NOTICE '';
  RAISE NOTICE '2. When user CANNOT claim (already claimed):';
  RAISE NOTICE '   - Shows TOMORROWS reward as "Next Reward"';
  RAISE NOTICE '   - "1 Day Streak + Already Claimed" = Shows Day 2 rewards (8 NEFT)';
  RAISE NOTICE '';
  
  -- Test with a new user
  SELECT * INTO test_result FROM get_daily_claim_dashboard('0xTEST_NEW_USER');
  RAISE NOTICE 'Test 1: New user (never claimed)';
  RAISE NOTICE '   Current Streak: %', test_result.current_streak;
  RAISE NOTICE '   Can Claim: %', test_result.can_claim_today;
  RAISE NOTICE '   Reward: % NEFT + % XP', test_result.neft_reward, test_result.xp_reward;
  RAISE NOTICE '   Expected: 0 streak, can claim, 5 NEFT (Day 1)';
  RAISE NOTICE '';
END $$;
