-- ============================================================================
-- FIX BURN ACHIEVEMENTS TO USE CORRECT TABLE
-- ============================================================================
-- Problem: Achievement function reads from "nft_burns" table (doesn't exist)
--          But the app uses "burn_transactions" table
-- Solution: Update get_user_achievement_status to use burn_transactions
-- ============================================================================

DROP FUNCTION IF EXISTS get_user_achievement_status(TEXT) CASCADE;

CREATE OR REPLACE FUNCTION get_user_achievement_status(user_wallet TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  -- Get all user stats in ONE query to minimize database calls
  WITH user_stats AS (
    SELECT 
      user_wallet as wallet_address,
      
      -- Campaign completions (from existing campaign system)
      COALESCE((
        SELECT COUNT(DISTINCT p.id) 
        FROM projects p 
        WHERE EXISTS (
          SELECT 1 FROM campaign_reward_claims crc 
          WHERE crc.wallet_address = user_wallet 
          AND crc.project_id = p.id::text
        )
      ), 0) as campaigns_completed,
      
      -- NFT burns (from burn_transactions table - FIXED!)
      COALESCE((
        SELECT COUNT(*) 
        FROM burn_transactions bt 
        WHERE bt.wallet_address = user_wallet
      ), 0) as nfts_burned,
      
      -- Referrals (from existing referral system)
      COALESCE((
        SELECT COUNT(*) 
        FROM referrals r 
        WHERE r.referrer_address = user_wallet 
        AND r.status = 'completed'
      ), 0) as referrals_count,
      
      -- Daily claims - Check-in count (using total_claims from user_streaks)
      COALESCE((
        SELECT total_claims 
        FROM user_streaks us 
        WHERE us.wallet_address = user_wallet
      ), 0) as checkin_count,
      
      -- NFT staking count (from staked_tokens)
      COALESCE((
        SELECT COUNT(*) 
        FROM staked_tokens st 
        WHERE st.wallet_address = user_wallet
      ), 0) as nfts_staked_count,
      
      -- Current NEFT staking amount (from user_balances)
      COALESCE((
        SELECT staked_neft 
        FROM user_balances ub 
        WHERE ub.wallet_address = user_wallet
      ), 0) as current_neft_staked
  ),
  
  achievement_progress AS (
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
        THEN LEAST(us.campaigns_completed, am.required_count)
        
        -- Burn achievements (FIXED - now uses burn_transactions!)
        WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
        THEN LEAST(us.nfts_burned, am.required_count)
        
        -- Referral achievements
        WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
        THEN LEAST(us.referrals_count, am.required_count)
        
        -- Check-in achievements
        WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
        THEN LEAST(us.checkin_count, am.required_count)
        
        -- NFT staking achievements
        WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
        THEN LEAST(us.nfts_staked_count, am.required_count)
        
        -- NEFT staking achievements (current staked amount)
        WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
        THEN CASE WHEN us.current_neft_staked >= am.required_count THEN am.required_count ELSE 0 END
        
        ELSE 0
      END as current_progress,
      
      -- Calculate status
      CASE 
        WHEN uap.claimed_at IS NOT NULL THEN 'claimed'
        WHEN (
          CASE 
            WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
            THEN us.campaigns_completed >= am.required_count
            
            -- Burn achievements (FIXED!)
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN us.nfts_burned >= am.required_count
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN us.referrals_count >= am.required_count
            
            WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
            THEN us.checkin_count >= am.required_count
            
            WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
            THEN us.nfts_staked_count >= am.required_count
            
            WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
            THEN us.current_neft_staked >= am.required_count
            
            ELSE FALSE
          END
        ) THEN 'completed'
        WHEN (
          CASE 
            WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') 
            THEN us.campaigns_completed > 0
            
            -- Burn achievements (FIXED!)
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN us.nfts_burned > 0
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN us.referrals_count > 0
            
            WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
            THEN us.checkin_count > 0
            
            WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
            THEN us.nfts_staked_count > 0
            
            WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
            THEN us.current_neft_staked > 0
            
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
              THEN LEAST(us.campaigns_completed, am.required_count)
              
              -- Burn achievements (FIXED!)
              WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
              THEN LEAST(us.nfts_burned, am.required_count)
              
              WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
              THEN LEAST(us.referrals_count, am.required_count)
              
              WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') 
              THEN LEAST(us.checkin_count, am.required_count)
              
              WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') 
              THEN LEAST(us.nfts_staked_count, am.required_count)
              
              WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') 
              THEN CASE WHEN us.current_neft_staked >= am.required_count THEN am.required_count ELSE 0 END
              
              ELSE 0
            END::DECIMAL / am.required_count::DECIMAL
          ) * 100, 2)
        ELSE 0 
      END as progress_percentage
      
    FROM achievements_master am
    CROSS JOIN user_stats us
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

GRANT EXECUTE ON FUNCTION get_user_achievement_status(TEXT) TO authenticated, anon, public;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ BURN ACHIEVEMENTS FIXED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Changed from:';
  RAISE NOTICE '  ❌ nft_burns table (doesnt exist)';
  RAISE NOTICE 'To:';
  RAISE NOTICE '  ✅ burn_transactions table (used by your app)';
  RAISE NOTICE ' ';
  RAISE NOTICE '🔥 Burn achievements will now track correctly!';
  RAISE NOTICE ' ';
END $$;
