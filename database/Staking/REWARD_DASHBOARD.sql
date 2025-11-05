-- ============================================================================
-- STAKING REWARDS DASHBOARD
-- ============================================================================
-- Single query to view complete staking rewards status
-- Run this anytime to see a comprehensive overview
-- ============================================================================

-- DASHBOARD: Complete Staking Overview
SELECT 
    '🎯 STAKING REWARDS DASHBOARD' as title,
    CURRENT_TIMESTAMP as report_time;

-- ============================================================================
-- SECTION 1: Active Staking Summary
-- ============================================================================
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '📊 ACTIVE STAKING SUMMARY' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

WITH nft_stakes AS (
    SELECT 
        wallet_address,
        COUNT(*) as nft_count,
        SUM(daily_reward) as nft_daily_reward
    FROM staked_nfts
    GROUP BY wallet_address
),
token_stakes AS (
    SELECT 
        wallet_address,
        SUM(amount) as token_amount,
        SUM(daily_reward) as token_daily_reward
    FROM staked_tokens
    GROUP BY wallet_address
)
SELECT 
    COALESCE(n.wallet_address, t.wallet_address) as wallet,
    COALESCE(n.nft_count, 0) as staked_nfts,
    COALESCE(n.nft_daily_reward, 0) as nft_daily_reward,
    COALESCE(t.token_amount, 0) as staked_tokens,
    COALESCE(t.token_daily_reward, 0) as token_daily_reward,
    COALESCE(n.nft_daily_reward, 0) + COALESCE(t.token_daily_reward, 0) as total_daily_reward
FROM nft_stakes n
FULL OUTER JOIN token_stakes t ON n.wallet_address = t.wallet_address
ORDER BY total_daily_reward DESC;

-- ============================================================================
-- SECTION 2: Pending Rewards
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '💰 PENDING REWARDS (READY TO CLAIM)' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    wallet_address,
    SUM(total_nft_earned - total_nft_claimed) as nft_pending,
    SUM(total_token_earned - total_token_claimed) as token_pending,
    SUM(total_nft_earned - total_nft_claimed + total_token_earned - total_token_claimed) as total_pending,
    CASE 
        WHEN SUM(total_nft_earned - total_nft_claimed + total_token_earned - total_token_claimed) > 0 
        THEN '✅ CAN CLAIM'
        ELSE '⏳ NO REWARDS YET'
    END as status
FROM staking_rewards
GROUP BY wallet_address
HAVING SUM(total_nft_earned - total_nft_claimed + total_token_earned - total_token_claimed) >= 0
ORDER BY total_pending DESC;

-- ============================================================================
-- SECTION 3: Reward History (Last 7 Days)
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '📅 REWARD HISTORY (LAST 7 DAYS)' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    reward_date,
    COUNT(DISTINCT wallet_address) as wallets,
    SUM(nft_rewards) as total_nft_rewards,
    SUM(token_rewards) as total_token_rewards,
    SUM(nft_rewards + token_rewards) as total_rewards,
    COUNT(*) as reward_records
FROM staking_rewards
WHERE reward_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY reward_date
ORDER BY reward_date DESC;

-- ============================================================================
-- SECTION 4: Today's Rewards Detail
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '📆 TODAY''S REWARDS DETAIL' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    wallet_address,
    nft_rewards,
    token_rewards,
    nft_rewards + token_rewards as daily_total,
    total_nft_earned,
    total_token_earned,
    total_nft_claimed,
    total_token_claimed,
    created_at
FROM staking_rewards
WHERE reward_date = CURRENT_DATE
ORDER BY daily_total DESC;

-- ============================================================================
-- SECTION 5: Cumulative Statistics
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '📈 CUMULATIVE STATISTICS' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    wallet_address,
    COUNT(DISTINCT reward_date) as reward_days,
    SUM(nft_rewards) as sum_nft_rewards,
    SUM(token_rewards) as sum_token_rewards,
    MAX(total_nft_earned) as cumulative_nft,
    MAX(total_token_earned) as cumulative_token,
    MAX(total_nft_claimed) as total_nft_claimed,
    MAX(total_token_claimed) as total_token_claimed,
    MAX(total_nft_earned) - MAX(total_nft_claimed) as nft_unclaimed,
    MAX(total_token_earned) - MAX(total_token_claimed) as token_unclaimed
FROM staking_rewards
GROUP BY wallet_address
ORDER BY cumulative_nft + cumulative_token DESC;

-- ============================================================================
-- SECTION 6: Detailed NFT Breakdown
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '🎨 STAKED NFT BREAKDOWN BY RARITY' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    wallet_address,
    rarity,
    COUNT(*) as nft_count,
    AVG(daily_reward) as avg_daily_reward,
    SUM(daily_reward) as total_daily_reward,
    MIN(staked_at) as first_staked,
    MAX(staked_at) as last_staked
FROM staked_nfts
GROUP BY wallet_address, rarity
ORDER BY wallet_address, total_daily_reward DESC;

-- ============================================================================
-- SECTION 7: System Health Checks
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '🔍 SYSTEM HEALTH CHECKS' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

-- Check 1: Verify function exists
SELECT 
    '1. Reward Function' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'generate_daily_staking_rewards'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status;

-- Check 2: Verify rewards generated today
SELECT 
    '2. Today''s Generation' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM staking_rewards WHERE reward_date = CURRENT_DATE
        ) THEN '✅ GENERATED'
        ELSE '⚠️ NOT YET GENERATED'
    END as status;

-- Check 3: Check for duplicate records
SELECT 
    '3. Duplicate Records' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT wallet_address, reward_date
            FROM staking_rewards
            GROUP BY wallet_address, reward_date
            HAVING COUNT(*) > 1
        ) THEN '❌ DUPLICATES FOUND'
        ELSE '✅ NO DUPLICATES'
    END as status;

-- Check 4: Verify cumulative tracking
SELECT 
    '4. Cumulative Tracking' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT wallet_address
            FROM staking_rewards
            GROUP BY wallet_address
            HAVING SUM(nft_rewards) > MAX(total_nft_earned)
               OR SUM(token_rewards) > MAX(total_token_earned)
        ) THEN '❌ TRACKING ERROR'
        ELSE '✅ TRACKING OK'
    END as status;

-- Check 5: Orphaned rewards check
SELECT 
    '5. Orphaned Rewards' as check_name,
    CASE 
        WHEN EXISTS (
            SELECT sr.wallet_address
            FROM staking_rewards sr
            WHERE sr.nft_rewards > 0
            AND NOT EXISTS (
                SELECT 1 FROM staked_nfts sn 
                WHERE sn.wallet_address = sr.wallet_address
            )
            AND sr.reward_date = CURRENT_DATE
        ) THEN '⚠️ ORPHANS DETECTED'
        ELSE '✅ NO ORPHANS'
    END as status;

-- ============================================================================
-- SECTION 8: Quick Actions
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '⚡ QUICK ACTIONS' as section;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;

SELECT 
    'Run these commands for common actions:' as instructions
UNION ALL
SELECT ''
UNION ALL
SELECT '-- Generate rewards manually:'
UNION ALL
SELECT 'SELECT generate_daily_staking_rewards();'
UNION ALL
SELECT ''
UNION ALL
SELECT '-- Get user summary:'
UNION ALL
SELECT 'SELECT get_user_staking_summary(''YOUR_WALLET_ADDRESS'');'
UNION ALL
SELECT ''
UNION ALL
SELECT '-- Claim NFT rewards:'
UNION ALL
SELECT 'SELECT claim_nft_rewards(''YOUR_WALLET_ADDRESS'');'
UNION ALL
SELECT ''
UNION ALL
SELECT '-- Claim token rewards:'
UNION ALL
SELECT 'SELECT claim_token_rewards(''YOUR_WALLET_ADDRESS'');'
UNION ALL
SELECT ''
UNION ALL
SELECT '-- Check user balance:'
UNION ALL
SELECT 'SELECT * FROM user_balances WHERE wallet_address = ''YOUR_WALLET_ADDRESS'';';

-- ============================================================================
-- FOOTER
-- ============================================================================
SELECT '' as blank;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
SELECT '✅ DASHBOARD COMPLETE' as footer;
SELECT CURRENT_TIMESTAMP as generated_at;
SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' as separator;
