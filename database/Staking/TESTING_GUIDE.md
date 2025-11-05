# 24-Hour Staking Rewards Testing Guide

## Overview
This guide explains how to test staking rewards generation after 24 hours for both NFT and token staking on the backend SQL.

## Prerequisites
1. Access to Supabase SQL Editor
2. At least one wallet with staked NFTs or tokens
3. `generate_daily_staking_rewards()` function deployed

## Quick Test Steps

### 1. Initial State Check
Run this to see current staking status:
```sql
-- Check staked NFTs
SELECT wallet_address, nft_id, rarity, daily_reward, staked_at 
FROM staked_nfts;

-- Check staked tokens
SELECT wallet_address, amount, daily_reward, staked_at 
FROM staked_tokens;

-- Check existing rewards
SELECT wallet_address, reward_date, nft_rewards, token_rewards, 
       total_nft_earned, total_token_earned
FROM staking_rewards
ORDER BY reward_date DESC;
```

### 2. Generate Rewards (Simulate 24 hours)
Run the reward generation function:
```sql
SELECT generate_daily_staking_rewards() as wallets_processed;
```

### 3. Verify Rewards Were Generated
Check if rewards were added:
```sql
SELECT 
    wallet_address,
    reward_date,
    nft_rewards,
    token_rewards,
    total_nft_earned,
    total_token_earned,
    created_at
FROM staking_rewards
WHERE reward_date = CURRENT_DATE
ORDER BY wallet_address;
```

### 4. Verify Reward Accuracy
Compare actual rewards with expected:
```sql
-- Expected NFT rewards
SELECT 
    wallet_address,
    SUM(daily_reward) as expected_daily_nft_reward
FROM staked_nfts
GROUP BY wallet_address;

-- Actual NFT rewards
SELECT 
    wallet_address,
    nft_rewards as actual_nft_reward
FROM staking_rewards
WHERE reward_date = CURRENT_DATE;
```

### 5. Test Claiming Rewards
```sql
-- Check pending rewards
SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- Claim NFT rewards
SELECT claim_nft_rewards('YOUR_WALLET_ADDRESS');

-- Claim token rewards
SELECT claim_token_rewards('YOUR_WALLET_ADDRESS');

-- Verify balance updated
SELECT wallet_address, total_neft_claimed, available_neft
FROM user_balances
WHERE wallet_address = 'YOUR_WALLET_ADDRESS';
```

## Using the Comprehensive Test Script

The `TEST_24_HOUR_REWARD_GENERATION.sql` script contains 7 sections:

### Section 1: Setup Check
- Verifies function exists
- Shows current staked assets
- Displays existing rewards
- Calculates expected rewards

### Section 2: Test Reward Generation
- Captures before state
- Runs reward generation
- Captures after state
- Compares results

### Section 3: Verify Accuracy
- Checks NFT reward accuracy
- Checks token reward accuracy
- Verifies cumulative tracking

### Section 4: Test Claiming
- Shows pending rewards
- Tests claim functions
- Verifies balance updates

### Section 5: Multi-Day Simulation
- Simulates 7 days of rewards
- Tests cumulative tracking over time

### Section 6: Edge Cases
- Tests with no staked assets
- Tests duplicate generation
- Checks for duplicates

### Section 7: Performance
- Monitors table size
- Checks for orphaned rewards

## Expected Results

### For NFT Staking
| Rarity | Daily Reward |
|--------|--------------|
| Common | 0.1 NEFT |
| Rare | 0.4 NEFT |
| Legendary | 1.0 NEFT |
| Platinum | 2.5 NEFT |
| Silver | 8.0 NEFT |
| Gold | 30.0 NEFT |

### For Token Staking
- Daily reward rate: 10% APY
- Formula: `(staked_amount * 0.10) / 365`
- Example: 1000 NEFT staked = 0.2740 NEFT per day

## Common Scenarios

### Scenario 1: First Day Rewards
```sql
-- Stake NFT
-- Wait for reward generation (or run manually)
SELECT generate_daily_staking_rewards();

-- Expected results:
-- - 1 record in staking_rewards for today
-- - nft_rewards = daily_reward from staked_nfts
-- - total_nft_earned = nft_rewards
-- - total_nft_claimed = 0
```

### Scenario 2: Multiple Days
```sql
-- Day 1: Generate rewards
SELECT generate_daily_staking_rewards();

-- Day 2: Generate rewards again
SELECT generate_daily_staking_rewards();

-- Expected results:
-- - 2 records in staking_rewards (one per day)
-- - total_nft_earned = sum of all daily rewards
-- - Each day has separate nft_rewards value
```

### Scenario 3: Claiming Rewards
```sql
-- Generate rewards
SELECT generate_daily_staking_rewards();

-- Claim rewards
SELECT claim_nft_rewards('YOUR_WALLET');

-- Expected results:
-- - total_nft_claimed = total_nft_earned
-- - user_balances.total_neft_claimed increases
-- - user_balances.available_neft increases
```

## Troubleshooting

### Problem: No rewards generated
**Check:**
```sql
-- Are there staked assets?
SELECT COUNT(*) FROM staked_nfts;
SELECT COUNT(*) FROM staked_tokens;

-- Does function exist?
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'generate_daily_staking_rewards';
```

### Problem: Rewards don't match expected
**Check:**
```sql
-- Verify daily_reward values are set correctly
SELECT nft_id, rarity, daily_reward FROM staked_nfts;
SELECT amount, daily_reward FROM staked_tokens;

-- Compare with rewards generated
SELECT wallet_address, nft_rewards, token_rewards 
FROM staking_rewards 
WHERE reward_date = CURRENT_DATE;
```

### Problem: Can't claim rewards
**Check:**
```sql
-- Are there unclaimed rewards?
SELECT 
    total_nft_earned - total_nft_claimed as nft_pending,
    total_token_earned - total_token_claimed as token_pending
FROM staking_rewards
WHERE wallet_address = 'YOUR_WALLET';

-- Check function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_name IN ('claim_nft_rewards', 'claim_token_rewards');
```

### Problem: Balance not updating after claim
**Check:**
```sql
-- Verify user_balances record exists
SELECT * FROM user_balances WHERE wallet_address = 'YOUR_WALLET';

-- Check if claim was recorded
SELECT total_nft_claimed, total_token_claimed 
FROM staking_rewards 
WHERE wallet_address = 'YOUR_WALLET';
```

## Automated Testing (Cron Job)

### Check if cron job exists:
```sql
SELECT jobid, schedule, command, active, jobname
FROM cron.job 
WHERE jobname = 'daily-staking-rewards';
```

### Create cron job (runs daily at midnight UTC):
```sql
SELECT cron.schedule(
    'daily-staking-rewards',
    '0 0 * * *',
    'SELECT generate_daily_staking_rewards();'
);
```

### Check cron job execution history:
```sql
SELECT 
    jrd.jobid,
    j.jobname,
    jrd.start_time,
    jrd.end_time,
    jrd.return_message,
    jrd.status
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.jobname = 'daily-staking-rewards'
ORDER BY jrd.start_time DESC 
LIMIT 10;
```

## Best Practices

1. **Always verify before claiming**: Check `get_user_staking_summary()` first
2. **Test with small amounts**: Start with minimal stakes for testing
3. **Monitor cumulative totals**: Ensure `total_*_earned` values are always increasing
4. **Check for duplicates**: Same wallet + same date should have only 1 record
5. **Verify balance updates**: Always check `user_balances` after claiming
6. **Track historical data**: Keep reward records for audit trails

## Integration Testing

### Full End-to-End Test:
```sql
-- 1. Stake NFT
INSERT INTO staked_nfts (wallet_address, nft_id, rarity, daily_reward, staked_at)
VALUES ('test_wallet', 'test_nft_1', 'Rare', 0.4, NOW());

-- 2. Generate rewards
SELECT generate_daily_staking_rewards();

-- 3. Check rewards generated
SELECT * FROM staking_rewards WHERE wallet_address = 'test_wallet';

-- 4. Get summary
SELECT get_user_staking_summary('test_wallet');

-- 5. Claim rewards
SELECT claim_nft_rewards('test_wallet');

-- 6. Verify balance
SELECT * FROM user_balances WHERE wallet_address = 'test_wallet';

-- 7. Cleanup
DELETE FROM staked_nfts WHERE wallet_address = 'test_wallet';
DELETE FROM staking_rewards WHERE wallet_address = 'test_wallet';
DELETE FROM user_balances WHERE wallet_address = 'test_wallet';
```

## Quick Reference Commands

```sql
-- Generate rewards
SELECT generate_daily_staking_rewards();

-- Check summary
SELECT get_user_staking_summary('YOUR_WALLET');

-- Claim NFT rewards
SELECT claim_nft_rewards('YOUR_WALLET');

-- Claim token rewards
SELECT claim_token_rewards('YOUR_WALLET');

-- View all rewards
SELECT * FROM staking_rewards WHERE wallet_address = 'YOUR_WALLET';

-- View balance
SELECT * FROM user_balances WHERE wallet_address = 'YOUR_WALLET';
```
