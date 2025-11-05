-- ============================================================================
-- FIX: Add Referral Rewards to Balance Aggregation
-- This adds referral_rewards table to the comprehensive balance aggregation
-- ============================================================================

CREATE OR REPLACE FUNCTION aggregate_user_rewards_from_all_sources(user_wallet TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
  
  -- Campaign rewards
  campaign_neft DECIMAL(18,8) := 0;
  campaign_xp INTEGER := 0;
  
  -- Daily claims
  daily_neft DECIMAL(18,8) := 0;
  daily_xp INTEGER := 0;
  
  -- Achievement rewards (claimed only)
  achievement_neft DECIMAL(18,8) := 0;
  achievement_xp INTEGER := 0;
  
  -- Staking rewards (claimed only)
  staking_neft DECIMAL(18,8) := 0;
  staking_xp INTEGER := 0;
  
  -- ✨ NEW: Referral rewards (automatic)
  referral_neft DECIMAL(18,8) := 0;
  referral_xp INTEGER := 0;
  
  -- Staked amounts (affects available_neft)
  staked_amount DECIMAL(18,8) := 0;
  
  -- Totals
  total_neft DECIMAL(18,8);
  total_xp INTEGER;
  available_neft DECIMAL(18,8);
BEGIN
  -- Validate input
  IF user_wallet IS NULL OR user_wallet = '' THEN
    RAISE EXCEPTION 'user_wallet parameter cannot be null or empty';
  END IF;

  -- 1. Aggregate from campaign_reward_claims table
  BEGIN
    SELECT 
      COALESCE(SUM(neft_reward), 0),
      COALESCE(SUM(xp_reward), 0)
    INTO campaign_neft, campaign_xp
    FROM campaign_reward_claims 
    WHERE wallet_address = user_wallet;
    
    RAISE LOG 'Campaign rewards for %: NEFT=%, XP=%', user_wallet, campaign_neft, campaign_xp;
  EXCEPTION WHEN OTHERS THEN
    campaign_neft := 0;
    campaign_xp := 0;
    RAISE LOG 'Error getting campaign rewards for %: %', user_wallet, SQLERRM;
  END;

  -- 2. Aggregate from daily_claims table
  BEGIN
    SELECT 
      COALESCE(SUM(base_neft_reward + bonus_neft_reward), 0),
      COALESCE(SUM(base_xp_reward + bonus_xp_reward), 0)
    INTO daily_neft, daily_xp
    FROM daily_claims 
    WHERE wallet_address = user_wallet;
    
    RAISE LOG 'Daily claims for %: NEFT=%, XP=%', user_wallet, daily_neft, daily_xp;
  EXCEPTION WHEN OTHERS THEN
    daily_neft := 0;
    daily_xp := 0;
    RAISE LOG 'Error getting daily claims for %: %', user_wallet, SQLERRM;
  END;

  -- 3. Aggregate from user_achievements table (claimed achievements only)
  BEGIN
    SELECT 
      COALESCE(SUM(neft_reward), 0),
      COALESCE(SUM(xp_reward), 0)
    INTO achievement_neft, achievement_xp
    FROM user_achievements ua
    JOIN achievements_master am ON ua.achievement_key = am.achievement_key
    WHERE ua.wallet_address = user_wallet 
      AND ua.status = 'completed' 
      AND ua.claimed_at IS NOT NULL;
    
    RAISE LOG 'Achievement rewards for %: NEFT=%, XP=%', user_wallet, achievement_neft, achievement_xp;
  EXCEPTION WHEN OTHERS THEN
    achievement_neft := 0;
    achievement_xp := 0;
    RAISE LOG 'Error getting achievement rewards for %: %', user_wallet, SQLERRM;
  END;

  -- 4. Aggregate from staking_rewards table (claimed rewards only)
  BEGIN
    SELECT 
      COALESCE(SUM(reward_amount), 0),
      0 -- Staking rewards are NEFT only, no XP
    INTO staking_neft, staking_xp
    FROM staking_rewards 
    WHERE wallet_address = user_wallet 
      AND is_claimed = true;
    
    RAISE LOG 'Staking rewards for %: NEFT=%, XP=%', user_wallet, staking_neft, staking_xp;
  EXCEPTION WHEN OTHERS THEN
    staking_neft := 0;
    staking_xp := 0;
    RAISE LOG 'Error getting staking rewards for %: %', user_wallet, SQLERRM;
  END;

  -- ✨ 5. NEW: Aggregate from referral_rewards table (automatic rewards)
  BEGIN
    SELECT 
      COALESCE(SUM(reward_amount), 0),
      0 -- Referrals earn NEFT only, no XP
    INTO referral_neft, referral_xp
    FROM referral_rewards 
    WHERE wallet_address = user_wallet 
      AND status = 'completed'; -- Only count fulfilled referrals
    
    RAISE LOG 'Referral rewards for %: NEFT=%, XP=%', user_wallet, referral_neft, referral_xp;
  EXCEPTION WHEN OTHERS THEN
    referral_neft := 0;
    referral_xp := 0;
    RAISE LOG 'Error getting referral rewards for %: %', user_wallet, SQLERRM;
  END;

  -- 6. Get currently staked amount from staked_tokens table
  BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO staked_amount
    FROM staked_tokens 
    WHERE wallet_address = user_wallet;
    
    RAISE LOG 'Staked amount for %: %', user_wallet, staked_amount;
  EXCEPTION WHEN OTHERS THEN
    staked_amount := 0;
    RAISE LOG 'Error getting staked amount for %: %', user_wallet, SQLERRM;
  END;

  -- ✨ Calculate totals from all sources (INCLUDING REFERRALS!)
  total_neft := COALESCE(campaign_neft, 0) + 
                COALESCE(daily_neft, 0) + 
                COALESCE(achievement_neft, 0) + 
                COALESCE(staking_neft, 0) + 
                COALESCE(referral_neft, 0); -- ← NEW!
                
  total_xp := COALESCE(campaign_xp, 0) + 
              COALESCE(daily_xp, 0) + 
              COALESCE(achievement_xp, 0) + 
              COALESCE(staking_xp, 0);
  
  -- Calculate available NEFT (total earned minus staked)
  available_neft := GREATEST(0, total_neft - COALESCE(staked_amount, 0));

  RAISE LOG 'Final totals for %: total_neft=%, total_xp=%, available_neft=%, staked=%', 
    user_wallet, total_neft, total_xp, available_neft, staked_amount;

  -- ✨ Build result JSON with detailed breakdown (INCLUDING REFERRALS!)
  SELECT json_build_object(
    'total_neft_claimed', total_neft,
    'total_xp_earned', total_xp,
    'available_neft', available_neft,
    'staked_neft', COALESCE(staked_amount, 0),
    'last_updated', NOW(),
    -- Detailed breakdown by source for debugging
    'breakdown', json_build_object(
      'campaign_neft', campaign_neft,
      'campaign_xp', campaign_xp,
      'daily_neft', daily_neft,
      'daily_xp', daily_xp,
      'achievement_neft', achievement_neft,
      'achievement_xp', achievement_xp,
      'staking_neft', staking_neft,
      'staking_xp', staking_xp,
      'referral_neft', referral_neft, -- ← NEW!
      'referral_xp', referral_xp,     -- ← NEW!
      'staked_amount', staked_amount
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Add trigger to auto-sync balance when referral reward is added
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_user_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-sync balance when any reward is claimed or added
  PERFORM sync_user_balance_from_all_sources(NEW.wallet_address);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_balance_on_referral_reward ON referral_rewards;

-- Create trigger for automatic referral rewards
CREATE TRIGGER sync_balance_on_referral_reward
AFTER INSERT OR UPDATE ON referral_rewards
FOR EACH ROW
WHEN (NEW.status = 'completed')
EXECUTE FUNCTION sync_user_balance_trigger();

-- ============================================================================
-- Test the updated aggregation function
-- ============================================================================

-- Test with a sample wallet (replace with real wallet for testing)
-- SELECT aggregate_user_rewards_from_all_sources('0x1234567890abcdef...');

COMMENT ON FUNCTION aggregate_user_rewards_from_all_sources IS 
'Aggregates user rewards from ALL sources including campaigns, daily claims, achievements, staking, and referrals. Returns comprehensive balance breakdown.';

-- ============================================================================
-- Verify referral_rewards table structure (optional check)
-- ============================================================================

DO $$
BEGIN
  -- Check if referral_rewards table has the required columns
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'referral_rewards' 
    AND column_name = 'wallet_address'
  ) THEN
    RAISE WARNING 'referral_rewards table missing wallet_address column!';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'referral_rewards' 
    AND column_name = 'reward_amount'
  ) THEN
    RAISE WARNING 'referral_rewards table missing reward_amount column!';
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'referral_rewards' 
    AND column_name = 'status'
  ) THEN
    RAISE WARNING 'referral_rewards table missing status column!';
  END IF;
  
  RAISE NOTICE 'Referral rewards aggregation setup complete!';
END $$;
