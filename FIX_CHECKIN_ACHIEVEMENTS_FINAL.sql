-- ============================================================================
-- FINAL FIX FOR CHECK-IN ACHIEVEMENTS
-- ============================================================================
-- Problem: get_user_achievement_status references "achievements_master" table
--          which doesn't exist! Need to create it first.
-- ============================================================================

-- Step 1: Drop and recreate the achievements_master table to ensure correct structure
DROP TABLE IF EXISTS achievements_master CASCADE;

CREATE TABLE achievements_master (
  achievement_key TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  icon TEXT,
  neft_reward INTEGER NOT NULL DEFAULT 0,
  xp_reward INTEGER NOT NULL DEFAULT 0,
  required_count INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 2: Insert achievement definitions
INSERT INTO achievements_master (achievement_key, title, description, category, icon, neft_reward, xp_reward, required_count, is_active, sort_order) VALUES
-- QUEST ACHIEVEMENTS
('first_quest', 'First Quest', 'Complete your first quest', 'quest', '⭐', 10, 10, 1, true, 1),
('quest_legend', 'Quest Legend', 'Complete 5 quests', 'quest', '🏆', 50, 50, 5, true, 2),
('quest_master', 'Quest Master', 'Complete 15 quests', 'quest', '👑', 150, 150, 15, true, 3),

-- BURN ACHIEVEMENTS
('first_burn', 'First Burn', 'Burn your first NFT', 'burn', '🔥', 10, 10, 1, true, 10),
('burn_enthusiast', 'Burn Enthusiast', 'Burn 10 NFTs', 'burn', '💥', 50, 50, 10, true, 11),
('burn_master', 'Burn Master', 'Burn 50 NFTs', 'burn', '⚡', 200, 200, 50, true, 12),

-- REFERRAL ACHIEVEMENTS
('first_referral', 'First Referral', 'Refer your first friend', 'referral', '🎁', 20, 20, 1, true, 20),
('referral_pro', 'Referral Pro', 'Refer 5 friends', 'referral', '🌟', 50, 50, 5, true, 21),
('referral_master', 'Referral Master', 'Refer 30 friends', 'referral', '💎', 100, 100, 30, true, 22),

-- CHECK-IN ACHIEVEMENTS (THE IMPORTANT ONES!)
('checkin_starter', 'Check-in Starter', 'Check in for 2 days', 'checkin', '📅', 5, 5, 2, true, 30),
('checkin_regular', 'Regular Visitor', 'Check in for 10 days', 'checkin', '📈', 30, 30, 10, true, 31),
('checkin_dedicated', 'Dedicated User', 'Check in for 30 days', 'checkin', '🏅', 100, 100, 30, true, 32),

-- NFT STAKING ACHIEVEMENTS
('first_nft_stake', 'First NFT Stake', 'Stake your first NFT', 'staking', '🎨', 15, 15, 1, true, 40),
('nft_staking_pro', 'NFT Staking Pro', 'Stake 5 NFTs', 'staking', '🖼️', 50, 50, 5, true, 41),
('nft_staking_master', 'NFT Staking Master', 'Stake 20 NFTs', 'staking', '🎭', 150, 150, 20, true, 42),

-- NEFT STAKING ACHIEVEMENTS
('first_neft_stake', 'First NEFT Stake', 'Stake 100 NEFT points', 'staking', '💰', 20, 20, 100, true, 43),
('neft_staking_pro', 'NEFT Staking Pro', 'Stake 500 NEFT points', 'staking', '💸', 50, 50, 500, true, 44),
('neft_staking_master', 'NEFT Staking Master', 'Stake 2000 NEFT points', 'staking', '💎', 100, 100, 2000, true, 45)

ON CONFLICT (achievement_key) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  required_count = EXCLUDED.required_count,
  neft_reward = EXCLUDED.neft_reward,
  xp_reward = EXCLUDED.xp_reward,
  icon = EXCLUDED.icon;

-- Step 3: Grant permissions
GRANT SELECT ON achievements_master TO authenticated, anon, public;

-- Step 4: Create indexes
CREATE INDEX IF NOT EXISTS idx_achievements_master_category ON achievements_master(category);
CREATE INDEX IF NOT EXISTS idx_achievements_master_active ON achievements_master(is_active);

-- ============================================================================
-- VERIFY THE FIX
-- ============================================================================
DO $$
DECLARE
  starter_def RECORD;
  regular_def RECORD;
  dedicated_def RECORD;
BEGIN
  SELECT * INTO starter_def FROM achievements_master WHERE achievement_key = 'checkin_starter';
  SELECT * INTO regular_def FROM achievements_master WHERE achievement_key = 'checkin_regular';
  SELECT * INTO dedicated_def FROM achievements_master WHERE achievement_key = 'checkin_dedicated';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ACHIEVEMENTS_MASTER TABLE CREATED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Check-in Achievement Definitions:';
  RAISE NOTICE '1. % - Requires % claims', starter_def.title, starter_def.required_count;
  RAISE NOTICE '2. % - Requires % claims', regular_def.title, regular_def.required_count;
  RAISE NOTICE '3. % - Requires % claims', dedicated_def.title, dedicated_def.required_count;
  RAISE NOTICE ' ';
  RAISE NOTICE '📊 The get_user_achievement_status function will now work!';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Expected Behavior:';
  RAISE NOTICE '✅ 1 claim = 1/2 Check-in Starter (50%% progress)';
  RAISE NOTICE '✅ 2 claims = Check-in Starter COMPLETED';
  RAISE NOTICE '✅ 10 claims = Regular Visitor COMPLETED';
  RAISE NOTICE '✅ 30 claims = Dedicated User COMPLETED';
  RAISE NOTICE ' ';
END $$;
