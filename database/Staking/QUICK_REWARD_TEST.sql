-- ============================================================================
-- QUICK 24-HOUR REWARD GENERATION TEST
-- ============================================================================
-- Copy and paste this entire script into Supabase SQL Editor
-- Replace 'YOUR_WALLET_ADDRESS' with your actual wallet address
-- ============================================================================

-- Step 1: Check current staked assets
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '📊 STEP 1: Current Staked Assets'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
    'NFT Staking' as type,
    wallet_address,
    COUNT(*) as staked_count,
    SUM(daily_reward) as daily_reward_total
FROM staked_nfts
GROUP BY wallet_address
UNION ALL
SELECT 
    'Token Staking' as type,
    wallet_address,
    COUNT(*) as staked_count,
    SUM(daily_reward) as daily_reward_total
FROM staked_tokens
GROUP BY wallet_address
ORDER BY type, wallet_address;

-- Step 2: Check existing rewards BEFORE generation
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '💰 STEP 2: Rewards BEFORE Generation'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
    wallet_address,
    SUM(total_nft_earned - total_nft_claimed) as nft_pending,
    SUM(total_token_earned - total_token_claimed) as token_pending,
    SUM(total_nft_earned - total_nft_claimed + total_token_earned - total_token_claimed) as total_pending
FROM staking_rewards
GROUP BY wallet_address;

-- Step 3: Generate rewards (simulate 24 hours)
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '⚙️  STEP 3: Generating Daily Rewards...'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
    generate_daily_staking_rewards() as wallets_processed,
    NOW() as generation_time;

-- Step 4: Check rewards AFTER generation
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ STEP 4: Rewards AFTER Generation'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
    wallet_address,
    SUM(total_nft_earned - total_nft_claimed) as nft_pending,
    SUM(total_token_earned - total_token_claimed) as token_pending,
    SUM(total_nft_earned - total_nft_claimed + total_token_earned - total_token_claimed) as total_pending
FROM staking_rewards
GROUP BY wallet_address;

-- Step 5: Verify today's rewards
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '🔍 STEP 5: Today\'s Reward Details'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

SELECT 
    wallet_address,
    reward_date,
    nft_rewards as nft_daily,
    token_rewards as token_daily,
    total_nft_earned as nft_cumulative,
    total_token_earned as token_cumulative,
    total_nft_claimed as nft_claimed,
    total_token_claimed as token_claimed,
    created_at
FROM staking_rewards
WHERE reward_date = CURRENT_DATE
ORDER BY wallet_address;

-- Step 6: Test getting summary for specific wallet
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '📊 STEP 6: Get Staking Summary (Replace YOUR_WALLET_ADDRESS below)'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- UNCOMMENT AND REPLACE WITH YOUR WALLET ADDRESS:
-- SELECT get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071');

\echo ''
\echo 'To test claiming rewards, uncomment and run these commands:'
\echo 'SELECT claim_nft_rewards(''0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'');'
\echo 'SELECT claim_token_rewards(''0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'');'

-- Step 7: Verify accuracy
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ STEP 7: Accuracy Verification'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

-- Compare expected vs actual NFT rewards
WITH expected_nft AS (
    SELECT wallet_address, SUM(daily_reward) as expected_reward
    FROM staked_nfts
    GROUP BY wallet_address
),
actual_nft AS (
    SELECT wallet_address, nft_rewards as actual_reward
    FROM staking_rewards
    WHERE reward_date = CURRENT_DATE
)
SELECT 
    COALESCE(e.wallet_address, a.wallet_address) as wallet,
    COALESCE(e.expected_reward, 0) as expected_nft,
    COALESCE(a.actual_reward, 0) as actual_nft,
    CASE 
        WHEN ABS(COALESCE(e.expected_reward, 0) - COALESCE(a.actual_reward, 0)) < 0.0001 THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END as nft_status
FROM expected_nft e
FULL OUTER JOIN actual_nft a ON e.wallet_address = a.wallet_address;

-- Compare expected vs actual token rewards
WITH expected_token AS (
    SELECT wallet_address, SUM(daily_reward) as expected_reward
    FROM staked_tokens
    GROUP BY wallet_address
),
actual_token AS (
    SELECT wallet_address, token_rewards as actual_reward
    FROM staking_rewards
    WHERE reward_date = CURRENT_DATE
)
SELECT 
    COALESCE(e.wallet_address, a.wallet_address) as wallet,
    COALESCE(e.expected_reward, 0) as expected_token,
    COALESCE(a.actual_reward, 0) as actual_token,
    CASE 
        WHEN ABS(COALESCE(e.expected_reward, 0) - COALESCE(a.actual_reward, 0)) < 0.0001 THEN '✅ MATCH'
        ELSE '❌ MISMATCH'
    END as token_status
FROM expected_token e
FULL OUTER JOIN actual_token a ON e.wallet_address = a.wallet_address;

-- Final summary
\echo ''
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo '✅ TEST COMPLETE - Summary'
\echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
\echo ''
\echo 'Next steps:'
\echo '1. Verify all statuses show ✅ MATCH'
\echo '2. Test claim functions with your wallet address'
\echo '3. Check user_balances table after claiming'
\echo ''
\echo 'To claim rewards, run:'
\echo 'SELECT claim_nft_rewards(''0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'');'
\echo 'SELECT claim_token_rewards(''0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'');'
\echo ''
