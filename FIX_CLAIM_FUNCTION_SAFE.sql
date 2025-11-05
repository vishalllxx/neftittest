-- ============================================================================
-- FIX CLAIM ACHIEVEMENT FUNCTION - Handle Missing Tables
-- ============================================================================
-- This updates the claim_achievement function to handle missing tables safely
-- ============================================================================

CREATE OR REPLACE FUNCTION claim_achievement(user_wallet TEXT, achievement_key_param TEXT)
RETURNS JSON AS $$
DECLARE
  achievement_record RECORD;
  is_completed BOOLEAN := FALSE;
  v_campaigns_completed INTEGER := 0;
  v_nfts_burned INTEGER := 0;
  v_referrals_count INTEGER := 0;
  v_checkin_count INTEGER := 0;
  v_nfts_staked_count INTEGER := 0;
  v_current_neft_staked INTEGER := 0;
BEGIN
  -- Get achievement details first
  SELECT 
    am.neft_reward,
    am.xp_reward,
    am.title,
    am.required_count,
    am.achievement_key
  INTO achievement_record
  FROM achievements_master am
  WHERE am.achievement_key = achievement_key_param 
    AND am.is_active = TRUE;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Achievement not found'
    );
  END IF;

  -- Check if already claimed
  IF EXISTS (
    SELECT 1 FROM user_achievement_progress 
    WHERE wallet_address = user_wallet 
    AND achievement_key = achievement_key_param 
    AND claimed_at IS NOT NULL
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Achievement already claimed'
    );
  END IF;

  -- Get user stats with error handling for missing tables
  -- Campaign completions
  BEGIN
    SELECT COUNT(DISTINCT p.id) INTO v_campaigns_completed
    FROM projects p 
    WHERE EXISTS (
      SELECT 1 FROM campaign_reward_claims crc 
      WHERE crc.wallet_address = user_wallet 
      AND crc.project_id = p.id::text
    );
  EXCEPTION WHEN OTHERS THEN
    v_campaigns_completed := 0;
  END;

  -- NFT burns
  BEGIN
    SELECT COUNT(*) INTO v_nfts_burned
    FROM nft_burns nb 
    WHERE nb.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_nfts_burned := 0;
  END;

  -- Referrals
  BEGIN
    SELECT COUNT(*) INTO v_referrals_count
    FROM referrals r 
    WHERE r.referrer_address = user_wallet 
    AND r.status = 'completed';
  EXCEPTION WHEN OTHERS THEN
    v_referrals_count := 0;
  END;

  -- Check-in count (total_claims from user_streaks)
  BEGIN
    SELECT total_claims INTO v_checkin_count
    FROM user_streaks us 
    WHERE us.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_checkin_count := 0;
  END;

  -- NFT staking count
  BEGIN
    SELECT COUNT(*) INTO v_nfts_staked_count
    FROM staked_tokens st 
    WHERE st.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_nfts_staked_count := 0;
  END;

  -- Current NEFT staking
  BEGIN
    SELECT staked_neft INTO v_current_neft_staked
    FROM user_balances ub 
    WHERE ub.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_current_neft_staked := 0;
  END;

  -- Check if achievement is completed based on type
  is_completed := CASE 
    -- Quest achievements
    WHEN achievement_key_param IN ('first_quest', 'quest_legend', 'quest_master') 
    THEN v_campaigns_completed >= achievement_record.required_count
    
    -- Burn achievements
    WHEN achievement_key_param IN ('first_burn', 'burn_enthusiast', 'burn_master') 
    THEN v_nfts_burned >= achievement_record.required_count
    
    -- Referral achievements
    WHEN achievement_key_param IN ('first_referral', 'referral_pro', 'referral_master') 
    THEN v_referrals_count >= achievement_record.required_count
    
    -- Check-in achievements (ALL 3)
    WHEN achievement_key_param IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
    THEN v_checkin_count >= achievement_record.required_count
    
    -- NFT staking achievements
    WHEN achievement_key_param IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
    THEN v_nfts_staked_count >= achievement_record.required_count
    
    -- NEFT staking achievements
    WHEN achievement_key_param IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
    THEN v_current_neft_staked >= achievement_record.required_count
    
    ELSE FALSE
  END;

  -- If not completed, return error
  IF NOT is_completed THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Achievement not completed yet'
    );
  END IF;

  -- Mark as claimed
  INSERT INTO user_achievement_progress (wallet_address, achievement_key, status, claimed_at)
  VALUES (user_wallet, achievement_key_param, 'claimed', NOW())
  ON CONFLICT (wallet_address, achievement_key) 
  DO UPDATE SET 
    status = 'claimed',
    claimed_at = NOW(),
    updated_at = NOW();

  -- Add rewards to user balance
  INSERT INTO user_balances (wallet_address, total_neft_claimed, total_xp_earned, available_neft, last_updated)
  VALUES (user_wallet, achievement_record.neft_reward, achievement_record.xp_reward, achievement_record.neft_reward, NOW())
  ON CONFLICT (wallet_address) 
  DO UPDATE SET
    total_neft_claimed = user_balances.total_neft_claimed + achievement_record.neft_reward,
    total_xp_earned = user_balances.total_xp_earned + achievement_record.xp_reward,
    available_neft = user_balances.available_neft + achievement_record.neft_reward,
    last_updated = NOW();

  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Achievement claimed successfully!',
    'neft_reward', achievement_record.neft_reward,
    'xp_reward', achievement_record.xp_reward,
    'title', achievement_record.title
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Error claiming achievement: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION claim_achievement(TEXT, TEXT) TO authenticated, anon, public;

SELECT '✅ CLAIM FUNCTION FIXED - Can now handle missing tables!' as status;
SELECT 'Try claiming an achievement again' as next_step;
