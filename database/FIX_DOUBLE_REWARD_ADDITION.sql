-- ============================================================================
-- FIX DOUBLE REWARD ADDITION ISSUE
-- ============================================================================
-- Prevents rewards from being counted twice by ensuring consistent tracking
-- and fixing the reward calculation formula to match your expected values
-- ============================================================================

-- First, let's fix the calculate_daily_reward function to match your expected values
DROP FUNCTION IF EXISTS calculate_daily_reward(INTEGER, TEXT);

CREATE OR REPLACE FUNCTION calculate_daily_reward(
  streak_count INTEGER,
  user_wallet TEXT DEFAULT NULL
)
RETURNS TABLE(
  base_neft DECIMAL(18,8),
  bonus_neft DECIMAL(18,8),
  base_xp INTEGER,
  bonus_xp INTEGER,
  reward_tier TEXT,
  nft_reward JSONB,
  is_milestone BOOLEAN
) AS $$
DECLARE
  milestone_record RECORD;
  base_daily_neft DECIMAL(18,8);
  base_daily_xp INTEGER;
BEGIN
  -- CORRECTED REWARD CALCULATION to match your expected values
  -- Day 1: 5 NEFT, 5 XP
  -- Day 2: 8 NEFT, 8 XP  
  -- Day 3: 10 NEFT, 10 XP (progressive increase)
  
  CASE 
    WHEN streak_count = 1 THEN
      base_daily_neft := 5.0;
      base_daily_xp := 5;
    WHEN streak_count = 2 THEN
      base_daily_neft := 8.0;
      base_daily_xp := 8;
    WHEN streak_count = 3 THEN
      base_daily_neft := 10.0;
      base_daily_xp := 10;
    ELSE
      -- Progressive scaling for higher streaks
      base_daily_neft := 10.0 + ((streak_count - 3) * 2.0);
      base_daily_xp := 10 + ((streak_count - 3) * 2);
  END CASE;
  
  -- Check if this streak count is a milestone
  SELECT * INTO milestone_record 
  FROM daily_claim_milestones 
  WHERE milestone_day = streak_count;
  
  IF FOUND THEN
    -- Milestone reward (overrides base calculation)
    RETURN QUERY SELECT 
      milestone_record.base_neft_reward,
      milestone_record.bonus_neft_reward,
      milestone_record.base_xp_reward,
      milestone_record.bonus_xp_reward,
      milestone_record.milestone_name,
      milestone_record.nft_reward,
      TRUE;
  ELSE
    -- Regular daily reward
    RETURN QUERY SELECT 
      base_daily_neft,
      0.0::DECIMAL(18,8), -- No bonus for regular days
      base_daily_xp,
      0::INTEGER, -- No bonus XP for regular days
      CASE 
        WHEN streak_count = 1 THEN 'Daily Starter'
        WHEN streak_count <= 7 THEN 'Building Momentum'
        WHEN streak_count <= 30 THEN 'Consistent Performer'
        WHEN streak_count <= 60 THEN 'Dedicated User'
        ELSE 'Legendary Streaker'
      END,
      NULL::JSONB,
      FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_daily_reward(INTEGER, TEXT) TO authenticated, anon, public;

-- Now fix the process_daily_claim function to prevent double counting
DROP FUNCTION IF EXISTS process_daily_claim(TEXT);

CREATE OR REPLACE FUNCTION process_daily_claim(user_wallet TEXT)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  current_streak INTEGER,
  neft_reward DECIMAL(18,8),
  xp_reward INTEGER,
  reward_tier TEXT,
  nft_reward JSONB,
  is_milestone BOOLEAN,
  total_neft_earned DECIMAL(18,8),
  total_xp_earned INTEGER
)
SECURITY DEFINER
LANGUAGE plpgsql AS $$
DECLARE
  user_record RECORD;
  reward_data RECORD;
  calculated_streak INTEGER;
  total_reward_neft DECIMAL(18,8);
  total_reward_xp INTEGER;
  hours_since_last_claim NUMERIC;
  user_total_neft DECIMAL(18,8);
  user_total_xp INTEGER;
BEGIN
  -- Get user streak record
  SELECT * INTO user_record FROM user_streaks us WHERE us.wallet_address = user_wallet;

  -- Check 24-hour cooldown
  IF user_record IS NOT NULL AND user_record.last_claimed_at IS NOT NULL THEN
    SELECT EXTRACT(EPOCH FROM (NOW() - user_record.last_claimed_at)) / 3600 INTO hours_since_last_claim;
    
    IF hours_since_last_claim < 24 THEN
      RETURN QUERY SELECT 
        FALSE, 
        CONCAT('Must wait ', ROUND(24 - hours_since_last_claim, 1), ' more hours before next claim')::TEXT,
        COALESCE(user_record.current_streak, 0), 
        0.0::DECIMAL(18,8), 
        0, 
        ''::TEXT, 
        NULL::JSONB, 
        FALSE,
        COALESCE(user_record.total_neft_earned, 0.0), 
        COALESCE(user_record.total_xp_earned, 0);
      RETURN;
    END IF;
  END IF;

  -- Check daily_claims table for same calendar date
  IF EXISTS (SELECT 1 FROM daily_claims dc WHERE dc.wallet_address = user_wallet AND dc.claim_date = CURRENT_DATE) THEN
    RETURN QUERY SELECT 
      FALSE, 'Already claimed today'::TEXT,
      COALESCE(user_record.current_streak, 0), 
      0.0::DECIMAL(18,8), 
      0, 
      ''::TEXT, 
      NULL::JSONB, 
      FALSE,
      COALESCE(user_record.total_neft_earned, 0.0), 
      COALESCE(user_record.total_xp_earned, 0);
    RETURN;
  END IF;

  -- Create or update user streak record
  IF user_record IS NULL THEN
    calculated_streak := 1;
    INSERT INTO user_streaks (
      wallet_address, current_streak, longest_streak, last_claim_date, 
      total_claims, streak_started_at, total_neft_earned, total_xp_earned,
      last_claimed_at
    ) VALUES (
      user_wallet, 1, 1, CURRENT_DATE, 1, CURRENT_DATE, 0, 0, NOW()
    );
  ELSE
    -- Calculate streak continuation
    IF user_record.last_claimed_at IS NOT NULL AND 
       user_record.last_claimed_at >= (NOW() - INTERVAL '48 hours') THEN
      calculated_streak := user_record.current_streak + 1;
    ELSE
      calculated_streak := 1;
    END IF;
  END IF;

  -- Get reward calculation
  SELECT * INTO reward_data FROM calculate_daily_reward(calculated_streak, user_wallet);
  
  total_reward_neft := reward_data.base_neft + reward_data.bonus_neft;
  total_reward_xp := reward_data.base_xp + reward_data.bonus_xp;

  -- Update user streaks (PRIMARY SOURCE OF TRUTH for totals)
  UPDATE user_streaks SET
    current_streak = calculated_streak,
    longest_streak = GREATEST(user_streaks.longest_streak, calculated_streak),
    last_claim_date = CURRENT_DATE,
    last_claimed_at = NOW(),
    total_claims = user_streaks.total_claims + 1,
    total_neft_earned = user_streaks.total_neft_earned + total_reward_neft,
    total_xp_earned = user_streaks.total_xp_earned + total_reward_xp
  WHERE user_streaks.wallet_address = user_wallet;

  -- Get updated totals for return value
  SELECT 
    user_streaks.total_neft_earned, 
    user_streaks.total_xp_earned 
  INTO user_total_neft, user_total_xp
  FROM user_streaks 
  WHERE user_streaks.wallet_address = user_wallet;

  -- Record the claim in daily_claims (for history tracking only)
  INSERT INTO daily_claims (
    wallet_address, claim_date, streak_count, 
    base_neft_reward, bonus_neft_reward, 
    base_xp_reward, bonus_xp_reward,
    nft_reward, reward_tier, claimed_at
  ) VALUES (
    user_wallet, CURRENT_DATE, calculated_streak,
    reward_data.base_neft, reward_data.bonus_neft,
    reward_data.base_xp, reward_data.bonus_xp,
    reward_data.nft_reward, reward_data.reward_tier, NOW()
  );

  -- Update user_balances table (SYNC with user_streaks - not additive)
  INSERT INTO user_balances (
    wallet_address, 
    total_neft_claimed, 
    total_xp_earned, 
    available_neft,
    staked_neft,
    last_updated
  ) VALUES (
    user_wallet, 
    user_total_neft,  -- Use the total from user_streaks, not additive
    user_total_xp,    -- Use the total from user_streaks, not additive
    user_total_neft,  -- Available = total for now
    0,                -- No staked initially
    NOW()
  )
  ON CONFLICT (wallet_address) DO UPDATE SET
    total_neft_claimed = user_total_neft,  -- SYNC, don't add
    total_xp_earned = user_total_xp,       -- SYNC, don't add  
    available_neft = user_total_neft,      -- Update available
    last_updated = NOW();

  -- Return success result with correct totals
  RETURN QUERY SELECT 
    TRUE,
    'Daily reward claimed successfully!'::TEXT,
    calculated_streak,
    total_reward_neft,
    total_reward_xp,
    reward_data.reward_tier,
    reward_data.nft_reward,
    reward_data.is_milestone,
    user_total_neft,  -- Total accumulated rewards
    user_total_xp;    -- Total accumulated XP
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_daily_claim(TEXT) TO authenticated, anon, public;

-- Test the corrected function
DO $$
DECLARE
  test_result RECORD;
BEGIN
  SELECT * INTO test_result FROM calculate_daily_reward(1, 'test');
  RAISE NOTICE 'Day 1 Test: NEFT=%, XP=%', 
    (test_result.base_neft + test_result.bonus_neft),
    (test_result.base_xp + test_result.bonus_xp);
    
  SELECT * INTO test_result FROM calculate_daily_reward(2, 'test');
  RAISE NOTICE 'Day 2 Test: NEFT=%, XP=%', 
    (test_result.base_neft + test_result.bonus_neft),
    (test_result.base_xp + test_result.bonus_xp);
    
  SELECT * INTO test_result FROM calculate_daily_reward(3, 'test');
  RAISE NOTICE 'Day 3 Test: NEFT=%, XP=%', 
    (test_result.base_neft + test_result.bonus_neft),
    (test_result.base_xp + test_result.bonus_xp);
END;
$$;

SELECT 'FIXED: Double reward addition prevented!' as status,
       'Rewards now: Day1=5/5, Day2=8/8, Day3=10/10. user_balances syncs with user_streaks.' as result;
