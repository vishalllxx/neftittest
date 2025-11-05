-- ============================================================================
-- CORRECTED DEFINITIVE ACHIEVEMENTS SYSTEM RESTORE
-- ============================================================================
-- This script fixes the enum error and includes all 3 check-in achievements
-- as shown in your original working system
-- ============================================================================

-- Step 1: Clean slate - remove all existing data safely
DELETE FROM user_achievement_progress WHERE achievement_key IS NOT NULL;
DELETE FROM achievements_master WHERE achievement_key IS NOT NULL;

-- Step 2: Insert the CORRECT achievement definitions with proper enum values
-- Using the exact structure from your working system
INSERT INTO achievements_master (
    achievement_key,
    title,
    description,
    category,
    icon,
    neft_reward,
    xp_reward,
    required_count,
    is_active,
    sort_order
) VALUES 
-- QUEST ACHIEVEMENTS
('first_quest', 'First Quest', 'Complete your first campaign', 'quest', '🎯', 5, 5, 1, true, 1),
('quest_legend', 'Quest Legend', 'Complete 10 campaigns', 'quest', '⭐', 70, 70, 10, true, 2),
('quest_master', 'Quest Master', 'Complete 25 campaigns', 'quest', '👑', 150, 150, 25, true, 3),

-- NFT BURNING ACHIEVEMENTS
('first_burn', 'First Burn', 'Burn NFTs first time', 'burn', '🔥', 5, 5, 1, true, 10),
('burn_enthusiast', 'Burn Enthusiast', 'Burn 25 NFTs', 'burn', '🌋', 50, 50, 25, true, 11),
('burn_master', 'Burn Master', 'Burn 100 NFTs', 'burn', '💥', 200, 200, 100, true, 12),

-- REFERRAL ACHIEVEMENTS (using 'referral' not 'social')
('first_referral', 'First Referral', 'Refer your first friend', 'referral', '🤝', 5, 5, 1, true, 20),
('referral_pro', 'Referral Pro', 'Refer 10 friends', 'referral', '👥', 30, 30, 10, true, 21),
('referral_master', 'Referral Master', 'Refer 30 friends', 'referral', '🌟', 100, 100, 30, true, 22),

-- CHECK-IN ACHIEVEMENTS (All 3 as shown in your image)
('checkin_starter', 'Check-in Starter', 'Check in for 2 days', 'checkin', '📅', 5, 5, 2, true, 30),
('checkin_regular', 'Regular Visitor', 'Check in for 10 days', 'checkin', '📈', 30, 30, 10, true, 31),
('checkin_dedicated', 'Dedicated User', 'Check in for 30 days', 'checkin', '🏅', 100, 100, 30, true, 32),

-- STAKING ACHIEVEMENTS - NFT Staking
('first_nft_stake', 'First NFT Stake', 'Stake one NFT', 'staking', '🔒', 5, 5, 1, true, 40),
('nft_staking_pro', 'NFT Staking Pro', 'Stake 10 NFTs', 'staking', '📦', 30, 30, 10, true, 41),
('nft_staking_master', 'NFT Staking Master', 'Stake 30 NFTs', 'staking', '💎', 100, 100, 30, true, 42),

-- STAKING ACHIEVEMENTS - NEFT Token Staking
('first_neft_stake', 'First NEFT Stake', 'Stake 50 NEFT points', 'staking', '💰', 5, 5, 50, true, 43),
('neft_staking_pro', 'NEFT Staking Pro', 'Stake 500 NEFT points', 'staking', '💵', 30, 30, 500, true, 44),
('neft_staking_master', 'NEFT Staking Master', 'Stake 2000 NEFT points', 'staking', '💸', 100, 100, 2000, true, 45);

-- Step 3: Create the WORKING function that matches your original system
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
      
      -- NFT burns (from existing burn tracking)
      COALESCE((
        SELECT COUNT(*) 
        FROM nft_burns nb 
        WHERE nb.wallet_address = user_wallet
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
        
        -- Burn achievements
        WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
        THEN LEAST(us.nfts_burned, am.required_count)
        
        -- Referral achievements
        WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
        THEN LEAST(us.referrals_count, am.required_count)
        
        -- Check-in achievements (ALL 3: checkin_starter, checkin_regular, checkin_dedicated)
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
            
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN us.nfts_burned >= am.required_count
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN us.referrals_count >= am.required_count
            
            -- Check-in achievements (ALL 3)
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
            
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
            THEN us.nfts_burned > 0
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
            THEN us.referrals_count > 0
            
            -- Check-in achievements (ALL 3)
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
              
              WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') 
              THEN LEAST(us.nfts_burned, am.required_count)
              
              WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') 
              THEN LEAST(us.referrals_count, am.required_count)
              
              -- Check-in achievements (ALL 3)
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

-- Step 4: Create the claim achievement function
CREATE OR REPLACE FUNCTION claim_achievement(user_wallet TEXT, achievement_key_param TEXT)
RETURNS JSON AS $$
DECLARE
  achievement_record RECORD;
  is_completed BOOLEAN := FALSE;
BEGIN
  -- Check if achievement is completed
  SELECT 
    am.neft_reward,
    am.xp_reward,
    am.title,
    (
      CASE 
        WHEN uap.claimed_at IS NOT NULL THEN FALSE -- Already claimed
        ELSE (
          CASE 
            WHEN am.achievement_key IN ('first_quest', 'quest_legend', 'quest_master') THEN
              COALESCE((
                SELECT COUNT(DISTINCT p.id) 
                FROM projects p 
                WHERE EXISTS (
                  SELECT 1 FROM campaign_reward_claims crc 
                  WHERE crc.wallet_address = user_wallet 
                  AND crc.project_id = p.id::text
                )
              ), 0) >= am.required_count
            
            WHEN am.achievement_key IN ('first_burn', 'burn_enthusiast', 'burn_master') THEN
              COALESCE((
                SELECT COUNT(*) 
                FROM nft_burns nb 
                WHERE nb.wallet_address = user_wallet
              ), 0) >= am.required_count
            
            WHEN am.achievement_key IN ('first_referral', 'referral_pro', 'referral_master') THEN
              COALESCE((
                SELECT COUNT(*) 
                FROM referrals r 
                WHERE r.referrer_address = user_wallet 
                AND r.status = 'completed'
              ), 0) >= am.required_count
            
            -- Check-in achievements (ALL 3)
            WHEN am.achievement_key IN ('checkin_starter', 'checkin_regular', 'checkin_dedicated') THEN
              COALESCE((
                SELECT total_claims 
                FROM user_streaks us 
                WHERE us.wallet_address = user_wallet
              ), 0) >= am.required_count
            
            WHEN am.achievement_key IN ('first_nft_stake', 'nft_staking_pro', 'nft_staking_master') THEN
              COALESCE((
                SELECT COUNT(*) 
                FROM staked_tokens st 
                WHERE st.wallet_address = user_wallet
              ), 0) >= am.required_count
            
            WHEN am.achievement_key IN ('first_neft_stake', 'neft_staking_pro', 'neft_staking_master') THEN
              COALESCE((
                SELECT staked_neft 
                FROM user_balances ub 
                WHERE ub.wallet_address = user_wallet
              ), 0) >= am.required_count
            
            ELSE FALSE
          END
        )
      END
    ) as is_completed
  INTO achievement_record
  FROM achievements_master am
  LEFT JOIN user_achievement_progress uap ON am.achievement_key = uap.achievement_key 
    AND uap.wallet_address = user_wallet
  WHERE am.achievement_key = achievement_key_param 
    AND am.is_active = TRUE;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Achievement not found'
    );
  END IF;
  
  IF NOT achievement_record.is_completed THEN
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

-- Step 5: Grant proper permissions
GRANT EXECUTE ON FUNCTION get_user_achievement_status(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION claim_achievement(TEXT, TEXT) TO authenticated, anon, public;

-- Step 6: Verification and testing
SELECT 'CORRECTED ACHIEVEMENTS SYSTEM RESTORED!' as status;

-- Show all achievements that should now be visible (should be 18 total)
SELECT 
  achievement_key,
  title,
  category,
  required_count,
  neft_reward,
  xp_reward,
  is_active
FROM achievements_master 
WHERE is_active = TRUE
ORDER BY sort_order;

-- Test the function with a dummy wallet
SELECT 'Testing function with dummy wallet:' as test_info;
SELECT get_user_achievement_status('test_wallet_address');

-- Show total count by category
SELECT 
  category,
  COUNT(*) as count
FROM achievements_master 
WHERE is_active = TRUE
GROUP BY category
ORDER BY category;
