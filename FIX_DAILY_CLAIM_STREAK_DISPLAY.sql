-- ============================================================================
-- FIX DAILY CLAIM STREAK DISPLAY
-- ============================================================================
-- Problem: Frontend shows stale streak value even after user misses claim window
-- Solution: Calculate actual current streak based on last_claim_date
-- 
-- Example scenario this fixes:
-- - User claims Day 1 at 10 AM (streak = 1)
-- - User doesn't claim Day 2
-- - On Day 3, frontend should show streak = 0 (not 1)
-- ============================================================================

-- Drop and recreate get_user_streak_info with streak expiration logic
DROP FUNCTION IF EXISTS get_user_streak_info(TEXT);

CREATE OR REPLACE FUNCTION get_user_streak_info(user_wallet TEXT)
RETURNS TABLE(
  current_streak INTEGER,
  longest_streak INTEGER,
  total_claims INTEGER,
  can_claim_today BOOLEAN,
  last_claim_date DATE
)
SECURITY DEFINER
LANGUAGE plpgsql AS $$
DECLARE
  user_record RECORD;
  can_claim BOOLEAN := FALSE;
  actual_streak INTEGER := 0;
BEGIN
  -- Get user streak record
  SELECT * INTO user_record FROM user_streaks WHERE wallet_address = user_wallet;
  
  IF user_record IS NULL THEN
    -- New user - never claimed before
    RETURN QUERY SELECT 0, 0, 0, TRUE, NULL::DATE;
  ELSE
    -- Check if user can claim today
    can_claim := NOT EXISTS (
      SELECT 1 FROM daily_claims 
      WHERE wallet_address = user_wallet 
      AND claim_date = CURRENT_DATE
    );
    
    -- CRITICAL FIX: Calculate actual current streak based on last claim date
    -- If user hasn't claimed for more than 1 day, their streak is broken (0)
    -- If they claimed yesterday, streak is still active
    -- If they already claimed today, use stored streak
    IF user_record.last_claim_date IS NULL THEN
      -- Never claimed before
      actual_streak := 0;
    ELSIF user_record.last_claim_date = CURRENT_DATE THEN
      -- Already claimed today - use stored streak
      actual_streak := user_record.current_streak;
    ELSIF user_record.last_claim_date = CURRENT_DATE - INTERVAL '1 day' THEN
      -- Claimed yesterday - streak is still active
      actual_streak := user_record.current_streak;
    ELSE
      -- Missed claim window (last claim was 2+ days ago) - streak broken
      actual_streak := 0;
    END IF;
    
    RETURN QUERY SELECT 
      actual_streak,
      user_record.longest_streak,
      user_record.total_claims,
      can_claim,
      user_record.last_claim_date;
  END IF;
END;
$$;

-- Update get_daily_claim_dashboard with same logic
DROP FUNCTION IF EXISTS get_daily_claim_dashboard(TEXT);

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
  
  -- Upcoming Milestones (JSON array)
  upcoming_milestones JSONB,
  
  -- Recent Claims History (JSON array)
  recent_claims JSONB,
  
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
  actual_streak INTEGER := 0;
  next_streak_calc INTEGER;
  milestones_json JSONB;
  claims_json JSONB;
  hours_until INTEGER := 0;
  minutes_until INTEGER := 0;
  cycle_day_calc INTEGER;
BEGIN
  -- Get user streak record
  SELECT * INTO user_record FROM user_streaks WHERE wallet_address = user_wallet;
  
  -- Check if user can claim today
  can_claim := NOT EXISTS (
    SELECT 1 FROM daily_claims 
    WHERE wallet_address = user_wallet 
    AND claim_date = CURRENT_DATE
  );
  
  -- CRITICAL FIX: Calculate actual current streak
  IF user_record IS NULL THEN
    actual_streak := 0;
    next_streak_calc := 1;
  ELSE
    -- Calculate actual current streak
    IF user_record.last_claim_date IS NULL THEN
      actual_streak := 0;
    ELSIF user_record.last_claim_date = CURRENT_DATE THEN
      -- Already claimed today
      actual_streak := user_record.current_streak;
    ELSIF user_record.last_claim_date = CURRENT_DATE - INTERVAL '1 day' THEN
      -- Claimed yesterday - streak still active
      actual_streak := user_record.current_streak;
    ELSE
      -- Missed claim window - streak broken
      actual_streak := 0;
    END IF;
    
    -- Calculate what the next streak will be if they claim now
    IF can_claim THEN
      IF user_record.last_claim_date = CURRENT_DATE - INTERVAL '1 day' THEN
        -- Claiming on consecutive day
        next_streak_calc := user_record.current_streak + 1;
      ELSE
        -- Starting new streak
        next_streak_calc := 1;
      END IF;
    ELSE
      -- Already claimed today
      next_streak_calc := user_record.current_streak;
    END IF;
  END IF;
  
  -- Calculate cycle day (1-7) for progressive rewards
  cycle_day_calc := ((next_streak_calc - 1) % 7) + 1;
  
  -- Get next reward calculation
  SELECT * INTO reward_data FROM calculate_daily_reward(next_streak_calc, user_wallet);
  
  -- Get upcoming milestones (single query, converted to JSON)
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'milestone_day', milestone_day,
        'milestone_name', milestone_name,
        'milestone_description', milestone_description,
        'total_neft_reward', base_neft_reward + bonus_neft_reward,
        'total_xp_reward', base_xp_reward + bonus_xp_reward,
        'nft_reward', nft_reward,
        'is_special_milestone', is_special_milestone,
        'icon_name', icon_name,
        'color_scheme', color_scheme
      ) ORDER BY milestone_day ASC
    ), '[]'::json
  )::JSONB INTO milestones_json
  FROM (
    SELECT milestone_day, milestone_name, milestone_description, 
           base_neft_reward, bonus_neft_reward, base_xp_reward, bonus_xp_reward,
           nft_reward, is_special_milestone, icon_name, color_scheme
    FROM daily_claim_milestones 
    WHERE milestone_day > COALESCE(actual_streak, 0)
    ORDER BY milestone_day ASC 
    LIMIT 5
  ) milestone_data;
  
  -- Get recent claims history (single query, converted to JSON)
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'claim_date', claim_date,
        'streak_count', streak_count,
        'total_neft_reward', base_neft_reward + bonus_neft_reward,
        'total_xp_reward', base_xp_reward + bonus_xp_reward,
        'reward_tier', reward_tier,
        'nft_reward', nft_reward,
        'claimed_at', claimed_at
      )
      ORDER BY claim_date DESC
    ), '[]'::json
  )::JSONB INTO claims_json
  FROM daily_claims 
  WHERE wallet_address = user_wallet
  ORDER BY claim_date DESC 
  LIMIT 10;
  
  -- Calculate time until next claim (if already claimed today)
  IF NOT can_claim AND user_record.last_claim_date IS NOT NULL THEN
    -- IMPROVED: Calculate exact time until next claim from last claim timestamp
    -- Get the most recent claim timestamp
    DECLARE
      last_claim_timestamp TIMESTAMP;
    BEGIN
      SELECT claimed_at INTO last_claim_timestamp
      FROM daily_claims
      WHERE wallet_address = user_wallet
      AND claim_date = CURRENT_DATE
      ORDER BY claimed_at DESC
      LIMIT 1;
      
      IF last_claim_timestamp IS NOT NULL THEN
        -- Calculate 24 hours from last claim
        DECLARE
          next_claim_time TIMESTAMP := last_claim_timestamp + INTERVAL '24 hours';
          time_diff INTERVAL := next_claim_time - NOW();
        BEGIN
          hours_until := EXTRACT(HOUR FROM time_diff);
          minutes_until := EXTRACT(MINUTE FROM time_diff);
          
          -- If time_diff is negative, user can claim (set to 0)
          IF hours_until < 0 THEN
            hours_until := 0;
            minutes_until := 0;
          END IF;
        END;
      END IF;
    END;
  END IF;
  
  -- Return comprehensive dashboard data with actual current streak
  RETURN QUERY SELECT 
    actual_streak,  -- FIXED: Return calculated actual streak, not stored value
    COALESCE(user_record.longest_streak, 0),
    COALESCE(user_record.total_claims, 0),
    can_claim,
    user_record.last_claim_date,
    COALESCE(user_record.total_neft_earned, 0.0),
    COALESCE(user_record.total_xp_earned, 0),
    user_record.streak_started_at,
    next_streak_calc,
    reward_data.base_neft + reward_data.bonus_neft,
    reward_data.base_xp + reward_data.bonus_xp,
    reward_data.reward_tier,
    cycle_day_calc,
    reward_data.is_milestone,
    milestones_json,
    claims_json,
    hours_until,
    minutes_until;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_streak_info(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION get_daily_claim_dashboard(TEXT) TO authenticated, anon, public;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Test the fix with a sample wallet
-- Replace 'YOUR_WALLET_ADDRESS' with actual wallet to test

-- Before fix: Would show old streak even if expired
-- After fix: Shows 0 if streak expired, current value if still active

SELECT 'Fix Applied Successfully!' as status,
       'get_user_streak_info now calculates actual current streak' as fix_description,
       'Streak shows 0 after missing claim window instead of stale value' as expected_behavior;

-- To test with your wallet:
-- SELECT * FROM get_user_streak_info('YOUR_WALLET_ADDRESS');
-- SELECT * FROM get_daily_claim_dashboard('YOUR_WALLET_ADDRESS');
