-- FIX FOR YOUR ACTUAL STAKING_REWARDS SCHEMA
-- Based on the hybrid schema with both old and new columns

-- ============================================================================
-- OPTION 1: Insert using NEW schema columns (reward_type, reward_amount)
-- ============================================================================

-- Replace 'YOUR_WALLET_ADDRESS' with your actual wallet address
INSERT INTO staking_rewards (
    wallet_address,
    reward_date,
    reward_type,
    source_id,
    reward_amount,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed
)
SELECT 
    wallet_address,
    CURRENT_DATE,
    'token_staking',
    id::TEXT,  -- source_id is TEXT, not UUID
    daily_reward,
    0,  -- nft_earned_today
    daily_reward,  -- token_earned_today
    daily_reward,  -- total_earned
    FALSE
FROM staked_tokens
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
ON CONFLICT (wallet_address, reward_date, reward_type, source_id) 
DO UPDATE SET
    reward_amount = EXCLUDED.reward_amount,
    token_earned_today = EXCLUDED.token_earned_today,
    total_earned = EXCLUDED.total_earned,
    last_updated = NOW();

-- ============================================================================
-- OPTION 2: Insert using OLD schema columns (if your get_user_staking_summary reads from old columns)
-- ============================================================================

INSERT INTO staking_rewards (
    wallet_address,
    reward_date,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed
)
SELECT 
    wallet_address,
    CURRENT_DATE,
    0 as nft_earned_today,
    COALESCE(SUM(daily_reward), 0) as token_earned_today,
    COALESCE(SUM(daily_reward), 0) as total_earned,
    FALSE
FROM staked_tokens
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
GROUP BY wallet_address
ON CONFLICT (wallet_address, reward_date, reward_type, source_id) 
DO UPDATE SET
    token_earned_today = EXCLUDED.token_earned_today,
    total_earned = EXCLUDED.total_earned,
    last_updated = NOW();

-- ============================================================================
-- Verify it worked
-- ============================================================================
SELECT 
    'Inserted rewards:' as info,
    wallet_address,
    reward_date,
    reward_type,
    reward_amount,
    nft_earned_today,
    token_earned_today,
    total_earned,
    is_claimed
FROM staking_rewards
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
ORDER BY created_at DESC;

-- ============================================================================
-- Test summary function
-- ============================================================================
SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- ============================================================================
-- TROUBLESHOOTING: If summary still shows 0, check which columns it reads
-- ============================================================================
-- Your get_user_staking_summary function might be reading from:
-- 1. reward_type + reward_amount (NEW schema)
-- 2. nft_earned_today + token_earned_today (OLD schema)
-- 
-- Run this to see what values are in the table:
SELECT 
    wallet_address,
    -- OLD schema columns
    nft_earned_today,
    token_earned_today,
    total_earned,
    -- NEW schema columns
    reward_type,
    reward_amount,
    source_id,
    -- Status
    is_claimed
FROM staking_rewards
WHERE wallet_address = 'YOUR_WALLET_ADDRESS';
