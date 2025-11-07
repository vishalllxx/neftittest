-- ============================================================================
-- EMERGENCY FIX - DOUBLE REWARDS ISSUE
-- ============================================================================
-- Problem: process_daily_claim() adds rewards to user_balances,
-- AND a trigger also adds rewards = DOUBLE REWARDS!
--
-- Solution: Remove the duplicate balance update from process_daily_claim
-- Let ONLY the trigger handle balance updates
-- ============================================================================

DROP FUNCTION IF EXISTS process_daily_claim(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION process_daily_claim(user_wallet TEXT)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  streak_count INTEGER,
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
  today_date DATE := (NOW() AT TIME ZONE 'UTC')::DATE;
BEGIN
  -- Check if already claimed today (based on UTC date)
  IF EXISTS (
    SELECT 1 FROM daily_claims 
    WHERE wallet_address = user_wallet 
    AND claim_date = today_date
  ) THEN
    RETURN QUERY SELECT 
      FALSE, 
      'Already claimed today'::TEXT,
      0, 
      0.0::DECIMAL(18,8), 
      0, 
      ''::TEXT, 
      NULL::JSONB, 
      FALSE,
      0.0::DECIMAL(18,8), 
      0;
    RETURN;
  END IF;

  -- Get or create user streak record
  SELECT * INTO user_record FROM user_streaks WHERE wallet_address = user_wallet;

  IF user_record IS NULL THEN
    -- New user - start at day 1
    calculated_streak := 1;
    INSERT INTO user_streaks (
      wallet_address, 
      current_streak, 
      longest_streak, 
      last_claim_date, 
      total_claims, 
      streak_started_at, 
      total_neft_earned, 
      total_xp_earned
    ) VALUES (
      user_wallet, 
      1, 
      1, 
      today_date, 
      1, 
      today_date, 
      0, 
      0
    );
  ELSE
    -- Existing user - check streak continuation
    IF user_record.last_claim_date = today_date - INTERVAL '1 day' THEN
      -- Claimed yesterday - continue streak
      calculated_streak := user_record.current_streak + 1;
    ELSIF user_record.last_claim_date >= today_date THEN
      -- Already claimed today (shouldn't happen due to check above, but safety)
      RETURN QUERY SELECT 
        FALSE, 
        'Already claimed today'::TEXT,
        user_record.current_streak,
        0.0::DECIMAL(18,8), 
        0, 
        ''::TEXT, 
        NULL::JSONB, 
        FALSE,
        0.0::DECIMAL(18,8), 
        0;
      RETURN;
    ELSE
      -- Streak broken - missed a day - reset to day 1
      calculated_streak := 1;
    END IF;
  END IF;

  -- Get reward calculation using the CORRECT function
  SELECT * INTO reward_data FROM calculate_daily_reward(calculated_streak, user_wallet);
  
  total_reward_neft := reward_data.base_neft + reward_data.bonus_neft;
  total_reward_xp := reward_data.base_xp + reward_data.bonus_xp;

  -- Update user streaks (FIXED: Qualify all column references)
  UPDATE user_streaks SET
    current_streak = calculated_streak,
    longest_streak = GREATEST(user_streaks.longest_streak, calculated_streak),
    last_claim_date = today_date,
    total_claims = user_streaks.total_claims + 1,
    total_neft_earned = user_streaks.total_neft_earned + total_reward_neft,
    total_xp_earned = user_streaks.total_xp_earned + total_reward_xp,
    updated_at = NOW()
  WHERE user_streaks.wallet_address = user_wallet;

  -- Record the claim
  INSERT INTO daily_claims (
    wallet_address, 
    claim_date, 
    streak_count, 
    base_neft_reward, 
    bonus_neft_reward, 
    base_xp_reward, 
    bonus_xp_reward,
    nft_reward, 
    reward_tier
  ) VALUES (
    user_wallet, 
    today_date, 
    calculated_streak,
    reward_data.base_neft, 
    reward_data.bonus_neft,
    reward_data.base_xp, 
    reward_data.bonus_xp,
    reward_data.nft_reward, 
    reward_data.reward_tier
  );

  -- ⚠️ CRITICAL FIX: DO NOT update user_balances here!
  -- The trigger "daily_claims_balance_sync" will handle it automatically
  -- Removing this to prevent DOUBLE REWARDS:
  --
  -- OLD CODE (CAUSED DOUBLE REWARDS):
  -- INSERT INTO user_balances (wallet_address, total_neft_claimed, total_xp_earned, last_updated)
  -- VALUES (user_wallet, total_reward_neft, total_reward_xp, NOW())
  -- ON CONFLICT (wallet_address) DO UPDATE SET ...
  --
  -- NEW: Let the trigger handle balance updates only!

  -- Return success result
  RETURN QUERY SELECT 
    TRUE,
    'Daily reward claimed successfully!'::TEXT,
    calculated_streak,
    total_reward_neft,
    total_reward_xp,
    reward_data.reward_tier,
    reward_data.nft_reward,
    reward_data.is_milestone,
    total_reward_neft,
    total_reward_xp;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_daily_claim(TEXT) TO authenticated, anon, public;

-- ============================================================================
-- Test the fix
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ DOUBLE REWARDS FIX APPLIED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Changes:';
  RAISE NOTICE '1. Removed duplicate user_balances update from process_daily_claim()';
  RAISE NOTICE '2. Only the trigger will update user_balances now';
  RAISE NOTICE '3. No more double rewards!';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT: Test with a new wallet to verify!';
  RAISE NOTICE '';
END $$;
