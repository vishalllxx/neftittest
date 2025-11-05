-- ============================================================================
-- UPDATE ACHIEVEMENT FUNCTION TO HANDLE MISSING TABLES
-- ============================================================================
-- This updates the function to handle missing tables gracefully
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_achievement_status(user_wallet TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
  v_campaigns_completed INTEGER := 0;
  v_nfts_burned INTEGER := 0;
  v_referrals_count INTEGER := 0;
  v_checkin_count INTEGER := 0;
  v_nfts_staked_count INTEGER := 0;
  v_current_neft_staked INTEGER := 0;
BEGIN
  -- Get campaign completions (with error handling)
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

  -- Get NFT burns (with error handling)
  BEGIN
    SELECT COUNT(*) INTO v_nfts_burned
    FROM nft_burns nb 
    WHERE nb.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_nfts_burned := 0;
  END;

  -- Get referrals (with error handling)
  BEGIN
    SELECT COUNT(*) INTO v_referrals_count
    FROM referrals r 
    WHERE r.referrer_address = user_wallet 
    AND r.status = 'completed';
  EXCEPTION WHEN OTHERS THEN
    v_referrals_count := 0;
  END;

  -- Get check-in count (with error handling)
  BEGIN
    SELECT total_claims INTO v_checkin_count
    FROM user_streaks us 
    WHERE us.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_checkin_count := 0;
  END;

  -- Get NFT staking count (with error handling)
  BEGIN
    SELECT COUNT(*) INTO v_nfts_staked_count
    FROM staked_tokens st 
    WHERE st.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_nfts_staked_count := 0;
  END;

  -- Get current NEFT staking amount (with error handling)
  BEGIN
    SELECT staked_neft INTO v_current_neft_staked
    FROM user_balances ub 
    WHERE ub.wallet_address = user_wallet;
  EXCEPTION WHEN OTHERS THEN
    v_current_neft_staked := 0;
  END;

  -- Build the achievement response
  WITH achievement_progress AS (
    SELECT 
      am.achievement_key,
      am.title,
      am.description,
      am.category::text,
      am.icon,
      am.neft_reward,
      am.xp_reward,
      am.required_count,
      am.sort_order,
      
      -- Calculate current progress based on achievement type
      CASE 
        -- Quest achievements
        WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
        THEN LEAST(v_campaigns_completed, am.required_count)
        
        -- Burn achievements
        WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
        THEN LEAST(v_nfts_burned, am.required_count)
        
        -- Referral achievements
        WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
        THEN LEAST(v_referrals_count, am.required_count)
        
        -- Check-in achievements (ALL 3)
        WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
        THEN LEAST(v_checkin_count, am.required_count)
        
        -- NFT staking achievements
        WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
        THEN LEAST(v_nfts_staked_count, am.required_count)
        
        -- NEFT staking achievements
        WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
        THEN CASE WHEN v_current_neft_staked >= am.required_count THEN am.required_count ELSE 0 END
        
        ELSE 0
      END as current_progress,
      
      -- Calculate status
      CASE 
        WHEN uap.claimed_at IS NOT NULL THEN 'claimed'
        WHEN (
          CASE 
            WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
            THEN v_campaigns_completed >= am.required_count
            
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN v_nfts_burned >= am.required_count
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN v_referrals_count >= am.required_count
            
            WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
            THEN v_checkin_count >= am.required_count
            
            WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
            THEN v_nfts_staked_count >= am.required_count
            
            WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
            THEN v_current_neft_staked >= am.required_count
            
            ELSE FALSE
          END
        ) THEN 'completed'
        WHEN (
          CASE 
            WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
            THEN v_campaigns_completed > 0
            
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN v_nfts_burned > 0
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN v_referrals_count > 0
            
            WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
            THEN v_checkin_count > 0
            
            WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
            THEN v_nfts_staked_count > 0
            
            WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
            THEN v_current_neft_staked > 0
            
            ELSE FALSE
          END
        ) THEN 'in_progress'
        ELSE 'locked'
      END as status,
      
      uap.claimed_at,
      
      -- Calculate progress percentage
      CASE 
        WHEN am.required_count > 0 THEN 
          ROUND((
            CASE 
              WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
              THEN LEAST(v_campaigns_completed, am.required_count)
              
              WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
              THEN LEAST(v_nfts_burned, am.required_count)
              
              WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
              THEN LEAST(v_referrals_count, am.required_count)
              
              WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
              THEN LEAST(v_checkin_count, am.required_count)
              
              WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
              THEN LEAST(v_nfts_staked_count, am.required_count)
              
              WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
              THEN CASE WHEN v_current_neft_staked >= am.required_count THEN am.required_count ELSE 0 END
              
              ELSE 0
            END::DECIMAL / am.required_count::DECIMAL
          ) * 100, 2)
        ELSE 0 
      END as progress_percentage
      
    FROM achievements_master am
    LEFT JOIN user_achievement_progress uap ON am.achievement_key = uap.achievement_key 
      AND uap.wallet_address = user_wallet
    WHERE am.is_active = TRUE
  )
  
  SELECT json_agg(
    json_build_object(
      'achievement_key', achievement_key,
      'title', title,
      'description', description,
      'category', category,
      'icon', icon,
      'neft_reward', neft_reward,
      'xp_reward', xp_reward,
      'required_count', required_count,
      'current_progress', current_progress,
      'status', status,
      'claimed_at', claimed_at,
      'progress_percentage', progress_percentage,
      'sort_order', sort_order
    ) ORDER BY sort_order
  ) INTO result
  FROM achievement_progress;
  
  RETURN COALESCE(result, '[]'::json);
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'error', true,
      'message', 'Error getting achievements: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_achievement_status(TEXT) TO authenticated, anon, public;

SELECT '✅ FUNCTION UPDATED TO HANDLE MISSING TABLES!' as status;
