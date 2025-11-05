# Pending Rewards Issue - Diagnosis & Solution

## Problem Description

**Symptoms:**
- Staked NFTs showing correctly (e.g., 6 NFTs)
- Staked tokens showing correctly (e.g., 220 NEFT)
- Daily rewards calculated correctly (e.g., 4.90 NEFT for NFTs, 0.12 NEFT for tokens)
- **BUT: Pending rewards showing 0.0 NEFT** despite assets being staked for 2+ days
- Claim button says "No NFT Rewards Available" / "No Token Rewards Available"

## Root Cause

The staking reward system uses a **two-stage architecture**:

1. **Stage 1: Calculate Daily Rewards**
   - When users stake, the system calculates how much they should earn per day
   - This is stored in `staked_nfts.daily_reward` and `staked_tokens.daily_reward`
   - ✅ This part is working (you can see "Daily Rewards: 4.90 NEFT" in UI)

2. **Stage 2: Generate Actual Rewards** (❌ This is broken)
   - A **cron job** must run `generate_daily_staking_rewards()` function
   - This function creates entries in the `staking_rewards` table
   - The UI reads from `staking_rewards` to show pending rewards
   - **Without the cron job, no rewards are generated!**

## Why It Shows 0.0 NEFT

```
User stakes NFT
    ↓
daily_reward calculated: 0.5 NEFT/day ✅
    ↓
TIME PASSES (2 days)
    ↓
Cron job should generate rewards ❌ NOT RUNNING
    ↓
staking_rewards table: EMPTY ❌
    ↓
UI shows: Pending Rewards: 0.0 NEFT ❌
```

## Solution Overview

### Quick Fix (Immediate)
1. Run `generate_daily_staking_rewards()` manually in Supabase
2. Rewards will appear immediately
3. Refresh staking page

### Permanent Fix (Automatic)
1. Setup pg_cron extension
2. Create cron job to run every 6 hours
3. Rewards auto-generate going forward

## Step-by-Step Fix

### Option 1: Quick Fix (5 minutes)

1. **Open Supabase SQL Editor**
2. **Run this command:**
   ```sql
   SELECT generate_daily_staking_rewards();
   ```
3. **Check your rewards:**
   ```sql
   SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');
   ```
4. **Refresh your staking page** - rewards should now show!

### Option 2: Complete Fix (10 minutes)

**Run the diagnostic script:**
```bash
# Open file:
database/Staking/QUICK_FIX_PENDING_REWARDS.sql

# Replace YOUR_WALLET_ADDRESS_HERE with your actual wallet
# Run in Supabase SQL Editor
```

This will:
- ✅ Generate rewards immediately
- ✅ Setup automatic cron job (every 6 hours)
- ✅ Verify everything works

### Option 3: Full Diagnosis (if issues persist)

**Run the comprehensive diagnostic:**
```bash
# Open file:
database/Staking/DIAGNOSE_AND_FIX_PENDING_REWARDS.sql

# Replace YOUR_WALLET_ADDRESS_HERE with your actual wallet
# Run in Supabase SQL Editor
```

This will:
- 🔍 Check all staking tables
- 🔍 Verify cron job status
- 🔍 Test reward generation function
- ✅ Generate rewards manually
- ✅ Setup automatic cron job
- 📊 Provide detailed status report

## Cron Job Configuration

### Recommended Schedule: Every 6 Hours
```sql
SELECT cron.schedule(
    'generate-staking-rewards-6h',
    '0 */6 * * *',  -- Runs at 00:00, 06:00, 12:00, 18:00 UTC
    $$SELECT generate_daily_staking_rewards();$$
);
```

### Alternative Schedules:

**Daily (midnight UTC):**
```sql
'0 0 * * *'  -- Once per day
```

**Every 12 hours:**
```sql
'0 */12 * * *'  -- Twice per day
```

**Every hour (high load):**
```sql
'0 * * * *'  -- 24 times per day
```

## Verification

### Check Cron Job Status
```sql
-- View all cron jobs
SELECT * FROM cron.job;

-- View execution history
SELECT * 
FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 10;
```

### Check Rewards Table
```sql
-- View your rewards
SELECT 
    reward_date,
    nft_earned_today,
    token_earned_today,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = 'YOUR_WALLET_ADDRESS'
ORDER BY reward_date DESC;
```

### Test Summary Function
```sql
SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');
```

Expected output:
```json
{
  "staked_nfts_count": 6,
  "staked_tokens_amount": 220,
  "nft_pending_rewards": 9.8,  // Should NOT be 0
  "token_pending_rewards": 0.24,  // Should NOT be 0
  "total_pending_rewards": 10.04,
  "daily_nft_rewards": 4.9,
  "daily_token_rewards": 0.12
}
```

## Manual Generation

You can always trigger reward generation manually:

```sql
-- Generate rewards for all users
SELECT generate_daily_staking_rewards();

-- Returns:
{
  "success": true,
  "wallets_processed": 5,
  "total_nft_rewards": 15.5,
  "total_token_rewards": 2.3,
  "timestamp": "2025-10-14T07:47:00Z"
}
```

## Expected Behavior After Fix

### Before Fix:
- Daily Rewards: 4.90 NEFT ✅ (showing correctly)
- Pending Rewards: 0.0 NEFT ❌ (incorrect)
- Claim button: Disabled ❌

### After Fix:
- Daily Rewards: 4.90 NEFT ✅
- Pending Rewards: 9.8 NEFT ✅ (2 days × 4.90)
- Claim button: **Enabled** "Claim 9.8000 NEFT" ✅

## Troubleshooting

### Issue: Function doesn't exist
**Error:** `function generate_daily_staking_rewards() does not exist`

**Fix:** Deploy the reward generation function first:
```bash
database/Staking/FIX_02_REWARD_GENERATION_FINAL.sql
```

### Issue: pg_cron extension not found
**Error:** `extension "pg_cron" does not exist`

**Fix:** Enable extension (Supabase should have this by default):
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

If not available, contact Supabase support or use manual generation.

### Issue: Rewards still showing 0.0
**Possible causes:**
1. Function ran but failed silently
2. Wallet address mismatch (check case sensitivity)
3. No staked assets in database

**Debug:**
```sql
-- Check function output
SELECT generate_daily_staking_rewards();

-- Check staked assets
SELECT * FROM staked_nfts WHERE wallet_address = 'YOUR_WALLET';
SELECT * FROM staked_tokens WHERE wallet_address = 'YOUR_WALLET';

-- Check rewards table
SELECT * FROM staking_rewards WHERE wallet_address = 'YOUR_WALLET';
```

### Issue: Cron job not running
**Check:**
```sql
-- View cron job
SELECT * FROM cron.job WHERE jobname LIKE '%staking%';

-- Check if active
SELECT active FROM cron.job WHERE jobname = 'generate-staking-rewards-6h';

-- View errors
SELECT * 
FROM cron.job_run_details 
WHERE status = 'failed' 
ORDER BY start_time DESC;
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER STAKES ASSETS                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STAKED_NFTS / STAKED_TOKENS TABLES                         │
│  • Records staking action                                    │
│  • Calculates daily_reward                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  CRON JOB (Every 6 hours)                                   │
│  • Calls generate_daily_staking_rewards()                   │
│  • Runs automatically via pg_cron                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  STAKING_REWARDS TABLE                                      │
│  • Stores actual generated rewards                          │
│  • Columns: nft_earned_today, token_earned_today           │
│  • is_claimed flag for claiming                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  get_user_staking_summary()                                 │
│  • Reads from staking_rewards                               │
│  • Calculates pending rewards                               │
│  • Returns summary to UI                                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  UI DISPLAYS PENDING REWARDS                                │
│  • Shows nft_pending_rewards                                │
│  • Shows token_pending_rewards                              │
│  • Enables claim button if > 0.01                          │
└─────────────────────────────────────────────────────────────┘
```

## Files Reference

- **Quick Fix:** `QUICK_FIX_PENDING_REWARDS.sql`
- **Full Diagnostic:** `DIAGNOSE_AND_FIX_PENDING_REWARDS.sql`
- **Cron Status Check:** `CHECK_CRON_JOB_STATUS.sql`
- **Main Functions:** `FIX_02_REWARD_GENERATION_FINAL.sql`

## Support

If issues persist after running the fix scripts:

1. Check Supabase logs for errors
2. Verify pg_cron extension is enabled
3. Ensure function has proper permissions
4. Check wallet address matches exactly (case-sensitive)

## Summary

**Problem:** Cron job not generating rewards  
**Solution:** Run manual generation + setup cron job  
**Time to fix:** 5-10 minutes  
**Result:** Pending rewards will show correctly and auto-generate every 6 hours
