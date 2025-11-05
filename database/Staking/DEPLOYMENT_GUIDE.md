# STAKING REWARD SYSTEM - DEPLOYMENT GUIDE
**Complete Fix Deployment Instructions**  
**Date:** 2025-01-11  
**Version:** 1.0.0

---

## 📋 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Rollback Plan](#rollback-plan)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 OVERVIEW

This deployment fixes **5 CRITICAL ISSUES** in the staking reward system:

1. ❌ **Wrong reward rates** → ✅ Rarity-based NFT rates (0.1-30 NEFT/day) + 20% APR for tokens
2. ❌ **Missing functions** → ✅ All EnhancedStakingService functions implemented
3. ❌ **No accumulation** → ✅ Automatic daily reward generation via cron
4. ❌ **Field mismatches** → ✅ Consistent field names across DB and frontend
5. ❌ **Schema gaps** → ✅ Rarity, source, and blockchain tracking added

### Expected Results After Deployment

- ✅ NFTs earn correct rarity-based rewards (Common: 0.1, Gold: 30 NEFT/day)
- ✅ Tokens earn 20% APR (not 36.5%)
- ✅ Rewards accumulate automatically every 6 hours
- ✅ Pending rewards visible in UI and growing daily
- ✅ Separate claim buttons work for NFT and token rewards
- ✅ Onchain/offchain NFT staking tracked separately

---

## ✅ PRE-DEPLOYMENT CHECKLIST

### Required Access
- [ ] Supabase project admin access
- [ ] SQL Editor access in Supabase dashboard
- [ ] Ability to create cron jobs (pg_cron extension)
- [ ] Database backup capability

### Environment Verification
- [ ] Identify environment: **Production** or **Staging**
- [ ] Confirm Supabase project URL
- [ ] Verify current staking data exists (check `staked_nfts`, `staked_tokens` tables)
- [ ] Review current user balance data

### Backup Strategy
- [ ] Manual backup via Supabase dashboard (recommended)
- [ ] SQL backup included in migration script (automatic)
- [ ] Document current state (counts, totals, sample data)

### Timing Considerations
- [ ] Schedule deployment during low-traffic period
- [ ] Allocate 30-60 minutes for full deployment
- [ ] Notify users of potential brief downtime (optional)

---

## 🚀 DEPLOYMENT STEPS

### STEP 1: Read the Analysis (5 minutes)

**File:** `ANALYSIS_STAKING_REWARD_ISSUES.md`

```bash
# Review all 5 critical issues identified
# Understand the impact and expected fixes
```

**Action Items:**
1. Read the complete analysis
2. Verify issues match your observations
3. Confirm expected reward rates (NFT rarity table, 20% APR for tokens)

---

### STEP 2: Deploy Schema & Functions (10 minutes)

**File:** `FIX_01_SCHEMA_AND_FUNCTIONS.sql`

**What it does:**
- Adds `nft_rarity`, `staking_source`, `blockchain` columns to `staked_nfts`
- Creates `get_daily_reward_for_rarity()` function
- Creates `stake_nft_with_source()` and `get_staked_nfts_with_source()` functions
- Adds alias functions for service compatibility

**Deployment:**

1. Open Supabase SQL Editor
2. Copy entire contents of `FIX_01_SCHEMA_AND_FUNCTIONS.sql`
3. Paste into SQL Editor
4. Click **RUN**
5. Verify output shows: `✅ FIX 01: SCHEMA AND FUNCTIONS DEPLOYED`

**Expected Output:**
```
✅ Schema Updates:
   - Added nft_rarity column to staked_nfts
   - Added staking_source column to staked_nfts
   - Added blockchain column to staked_nfts

✅ New Functions:
   - get_daily_reward_for_rarity(rarity)
   - stake_nft_with_source(...)
   - get_staked_nfts_with_source(wallet)

🎯 Reward Rate Verification:
   - Common NFT: 0.1 NEFT/day
   - Gold NFT: 30 NEFT/day

🚀 Ready for FIX_02_REWARD_GENERATION.sql
```

**Validation:**
```sql
-- Test the new function
SELECT get_daily_reward_for_rarity('Common');  -- Should return 0.1
SELECT get_daily_reward_for_rarity('Gold');    -- Should return 30.0
```

---

### STEP 3: Deploy Reward Generation Logic (15 minutes)

**File:** `FIX_02_REWARD_GENERATION.sql`

**What it does:**
- Fixes `stake_tokens()` to use 20% APR calculation
- Updates `generate_daily_staking_rewards()` with accumulative logic
- Sets up automatic cron jobs (midnight + every 6 hours)
- Updates unstake functions to finalize pending rewards

**Deployment:**

1. Open Supabase SQL Editor (new tab/session)
2. Copy entire contents of `FIX_02_REWARD_GENERATION.sql`
3. Paste into SQL Editor
4. Click **RUN**
5. Verify output shows successful deployment

**Expected Output:**
```
✅ Updated Functions:
   - stake_tokens() now uses 20% APR (not 36.5%)
   - generate_daily_staking_rewards() with accumulative logic

✅ Cron Job Scheduled:
   - Daily at 00:00 UTC (midnight) - 24-hour cycle
   - Real-time pending rewards via calculate_pending_rewards()

🎯 Reward Rate Verification:
   - 1000 NEFT staked at 20% APR = 0.54794520 NEFT/day

🔄 Triggering first reward generation...
✅ Result: {"success":true,...}
```

**ℹ️ How 24-Hour Rewards Work:**

The default `FIX_02_REWARD_GENERATION.sql` is configured for **24-hour reward generation**:

**Reward Accumulation:**
- Cron job runs **once daily at midnight UTC**
- Adds rewards to `staking_rewards` table
- Minimal database load

**Real-Time Display:**
- Frontend shows **live pending rewards** via `calculate_pending_rewards()` function
- Users see rewards growing in real-time even though generation is daily
- Formula: `accumulated_rewards + (time_since_last_generation × daily_rate)`

**Example User Experience:**
```
Day 1, 00:01 - Stake 1 Gold NFT (30 NEFT/day)
Day 1, 06:00 - Shows ~7.5 NEFT pending (real-time calculation)
Day 1, 12:00 - Shows ~15 NEFT pending (real-time calculation)
Day 2, 00:01 - Cron runs, records 30 NEFT in database
Day 2, 06:00 - Shows ~37.5 NEFT pending (30 accumulated + 7.5 realtime)
```

**🔧 Want Different Frequency?**

Use `FIX_02_REWARD_GENERATION_SINGLE_CRON.sql` for other options:
- 12 hours (twice daily)
- 6 hours (4× daily) 
- 1 hour (hourly)

**Validation:**
```sql
-- Verify cron job is scheduled
SELECT jobname, schedule, command 
FROM cron.job 
WHERE jobname LIKE '%staking%';

-- Expected: 1 row showing 'generate-staking-rewards-daily' with schedule '0 0 * * *'

-- Manually trigger reward generation (for testing)
SELECT generate_daily_staking_rewards();

-- Test real-time pending reward calculation
SELECT calculate_pending_rewards('YOUR_WALLET_ADDRESS', 'nft');
SELECT calculate_pending_rewards('YOUR_WALLET_ADDRESS', 'token');
```

---

### STEP 4: Deploy Claim Functions (10 minutes)

**File:** `FIX_03_CLAIM_FUNCTIONS.sql`

**What it does:**
- Updates `claim_nft_rewards_supabase_safe()` with real-time calculation
- Updates `claim_token_rewards_supabase_safe()` with validation
- Creates enhanced `claim_all_staking_rewards()` atomic function
- Adds claims history tracking

**⚠️ IMPORTANT: Claiming is ACCUMULATIVE**
- ✅ Claiming rewards **DOES NOT unstake** your NFT/tokens
- ✅ Rewards **CONTINUE accumulating** after every claim
- ✅ You can **claim multiple times** as rewards build up
- ✅ Assets earn rewards **until you unstake them**

Example: Stake Gold NFT (30 NEFT/day) → Claim after 3 days (90 NEFT) → **NFT stays staked** → Claim again after 2 more days (60 NEFT) → Repeat forever!

**Deployment:**

1. Open Supabase SQL Editor (new tab/session)
2. Copy entire contents of `FIX_03_CLAIM_FUNCTIONS.sql`
3. Paste into SQL Editor
4. Click **RUN**
5. Verify output shows successful deployment

**Expected Output:**
```
✅ Enhanced Claim Functions:
   - claim_nft_rewards_supabase_safe(wallet)
   - claim_token_rewards_supabase_safe(wallet)
   - claim_all_staking_rewards(wallet)

✅ Features Added:
   - Real-time pending reward calculation
   - Minimum 0.01 NEFT validation
   - Last claim timestamp updates
   - Claims history tracking
```

**Validation:**
```sql
-- Test claim validation (should fail if no rewards)
SELECT claim_nft_rewards_supabase_safe('test_wallet_address');
```

---

### STEP 5: Deploy Summary Functions (10 minutes)

**File:** `FIX_04_SUMMARY_FUNCTIONS.sql`

**What it does:**
- Updates `get_user_staking_summary()` to return correct field names
- Adds both `nft_pending_rewards` (new) and `claimable_nft_rewards` (old)
- Creates chain-specific summary function
- Adds detailed staking statistics and breakdown functions

**Deployment:**

1. Open Supabase SQL Editor (new tab/session)
2. Copy entire contents of `FIX_04_SUMMARY_FUNCTIONS.sql`
3. Paste into SQL Editor
4. Click **RUN**
5. Verify output shows successful deployment

**Expected Output:**
```
✅ Updated Functions:
   - get_user_staking_summary(wallet)
   - get_user_staking_summary_by_chain(wallet, chain)

✅ Field Names Updated:
   - nft_pending_rewards (NEW)
   - token_pending_rewards (NEW)
   - total_pending_rewards (NEW)
   - claimable_* fields (KEPT for compatibility)
```

**Validation:**
```sql
-- Test summary function (replace with actual wallet)
SELECT get_user_staking_summary('your_test_wallet_address');
```

---

### STEP 6: Run Data Migration (15 minutes)

**File:** `FIX_05_MIGRATION.sql`

**⚠️ CRITICAL:** This modifies existing data. Backups are created automatically.

**What it does:**
- Creates backup tables (staked_nfts_backup_20250111, etc.)
- Updates existing NFT stakes with correct rarity-based rates
- Updates existing token stakes to 20% APR
- Recalculates pending rewards with new rates
- Validates migration results

**Deployment:**

1. **IMPORTANT:** Verify steps 1-5 completed successfully
2. Open Supabase SQL Editor (new tab/session)
3. Copy entire contents of `FIX_05_MIGRATION.sql`
4. Paste into SQL Editor
5. Click **RUN** (this may take a few minutes)
6. Carefully review output for any warnings

**Expected Output:**
```
✅ BACKUP CREATED:
   - staked_nfts: X records backed up
   - staked_tokens: Y records backed up

🔄 Starting NFT migration - updating daily rates based on rarity...
  📝 NFT Example (Common) - Rate changed: 5.0 → 0.1 NEFT/day
  📝 NFT Example (Gold) - Rate changed: 5.0 → 30.0 NEFT/day
✅ NFT Migration Complete: X NFTs updated

🔄 Starting Token migration - updating to 20% APR...
  📝 Token stake 1000 NEFT - Rate: 0.0027... → 0.5479... NEFT/day
✅ Token Migration Complete: Y token stakes updated

=== MIGRATION VALIDATION ===
📊 Migration Summary:
   - Total staked NFTs: X
   - Total staked tokens: Y

✅ NFT Rate Validation by Rarity:
   - Gold (Z): 30.0 to 30.0 NEFT/day
   - Silver (Z): 8.0 to 8.0 NEFT/day
   ...

✅ Token Rate Validation (20% APR):
   ✓ Token 1000 NEFT has APR 20.00% (correct)

✅ ALL VALIDATIONS PASSED

🎉 STAKING REWARD SYSTEM FULLY FIXED!
```

**⚠️ If Warnings Appear:**
- Review the specific warnings
- Check backup tables are populated
- Contact technical team if critical errors

---

## ✅ POST-DEPLOYMENT VERIFICATION

### Verification Checklist (15 minutes)

Run these queries to verify the deployment:

```sql
-- 1. Verify NFT rarity rates
SELECT 
    nft_rarity,
    COUNT(*) as count,
    MIN(daily_rate) as min_rate,
    MAX(daily_rate) as max_rate
FROM staked_nfts
GROUP BY nft_rarity
ORDER BY MAX(daily_rate) DESC;

-- Expected Results:
-- Gold: 30.0, Silver: 8.0, Platinum: 2.5, Legendary: 1.0, Rare: 0.4, Common: 0.1

-- 2. Verify token APR is 20%
SELECT 
    amount,
    daily_rate,
    ((daily_rate * 365 / amount) * 100)::DECIMAL(10,2) as apr
FROM staked_tokens
LIMIT 10;

-- Expected: APR should be ~20.00% for all rows

-- 3. Verify cron jobs are scheduled
SELECT jobname, schedule, command 
FROM cron.job 
WHERE jobname LIKE '%staking%';

-- Expected: 2 jobs (daily + 6-hourly)

-- 4. Test reward generation manually
SELECT generate_daily_staking_rewards();

-- Expected: Success message with wallet count

-- 5. Test summary function with actual wallet
SELECT get_user_staking_summary('YOUR_WALLET_ADDRESS');

-- Expected: JSON with nft_pending_rewards, token_pending_rewards fields

-- 6. Verify backup tables exist
SELECT COUNT(*) FROM staked_nfts_backup_20250111;
SELECT COUNT(*) FROM staked_tokens_backup_20250111;

-- Expected: Same counts as current tables
```

### Frontend Integration Testing

1. **Test Pending Rewards Display:**
   - Login with wallet that has staked assets
   - Verify pending rewards show correct amounts
   - Wait 6 hours and verify rewards increased

2. **Test Claim Functions:**
   - Click "Claim NFT Rewards" button
   - Verify claim succeeds if > 0.01 NEFT
   - Verify balance increases correctly
   - Test "Claim Token Rewards" separately

3. **Test Staking New Assets:**
   - Stake a new NFT (verify rarity-based rate applied)
   - Stake tokens (verify 20% APR calculation)

---

## 🔄 ROLLBACK PLAN

### If Critical Issues Are Found

**IMMEDIATE ROLLBACK (Within 24 hours):**

```sql
-- 1. Restore from backup tables
BEGIN;

TRUNCATE staked_nfts;
INSERT INTO staked_nfts SELECT * FROM staked_nfts_backup_20250111;

TRUNCATE staked_tokens;
INSERT INTO staked_tokens SELECT * FROM staked_tokens_backup_20250111;

TRUNCATE staking_rewards;
INSERT INTO staking_rewards SELECT * FROM staking_rewards_backup_20250111;

COMMIT;

-- 2. Disable cron jobs
SELECT cron.unschedule('generate-staking-rewards');
SELECT cron.unschedule('generate-staking-rewards-6h');

-- 3. Verify rollback
SELECT COUNT(*) FROM staked_nfts;
SELECT COUNT(*) FROM staked_tokens;
```

**PARTIAL ROLLBACK (Specific tables):**

```sql
-- Rollback only NFTs
TRUNCATE staked_nfts;
INSERT INTO staked_nfts SELECT * FROM staked_nfts_backup_20250111;

-- Rollback only tokens
TRUNCATE staked_tokens;
INSERT INTO staked_tokens SELECT * FROM staked_tokens_backup_20250111;
```

---

## 📊 MONITORING & MAINTENANCE

### Daily Monitoring (First Week)

**Check these metrics daily:**

```sql
-- 1. Reward generation logs
SELECT * FROM cron.job_run_details 
WHERE jobname LIKE '%staking%' 
ORDER BY start_time DESC 
LIMIT 10;

-- 2. Total pending rewards by wallet
SELECT 
    wallet_address,
    (get_user_staking_summary(wallet_address)->>'nft_pending_rewards')::DECIMAL as nft_pending,
    (get_user_staking_summary(wallet_address)->>'token_pending_rewards')::DECIMAL as token_pending
FROM (SELECT DISTINCT wallet_address FROM staked_nfts) wallets;

-- 3. Claims activity
SELECT 
    wallet_address,
    claim_type,
    amount_claimed,
    claimed_at
FROM staking_claims_history
WHERE claimed_at > NOW() - INTERVAL '24 hours'
ORDER BY claimed_at DESC;

-- 4. Cron job health
SELECT 
    jobname,
    last_run,
    next_run,
    (SELECT status FROM cron.job_run_details 
     WHERE jobid = cron.job.jobid 
     ORDER BY start_time DESC LIMIT 1) as last_status
FROM cron.job
WHERE jobname LIKE '%staking%';
```

### Weekly Maintenance

- [ ] Verify cron jobs are running successfully
- [ ] Check for any error patterns in logs
- [ ] Validate reward accumulation is linear over time
- [ ] Monitor user claims activity
- [ ] Review backup table sizes (can delete after 30 days)

### Monthly Cleanup

```sql
-- After 30 days, remove backup tables (optional)
DROP TABLE IF EXISTS staked_nfts_backup_20250111;
DROP TABLE IF EXISTS staked_tokens_backup_20250111;
DROP TABLE IF EXISTS staking_rewards_backup_20250111;
```

---

## 🔧 TROUBLESHOOTING

### Issue: Pending rewards not increasing

**Diagnosis:**
```sql
-- Check if cron jobs are running
SELECT * FROM cron.job WHERE jobname LIKE '%staking%';
SELECT * FROM cron.job_run_details 
WHERE jobname LIKE '%staking%' 
ORDER BY start_time DESC LIMIT 5;
```

**Solution:**
```sql
-- Manually trigger reward generation
SELECT generate_daily_staking_rewards();

-- If cron jobs are not scheduled, re-run FIX_02_REWARD_GENERATION.sql
```

---

### Issue: Claim buttons disabled even with pending rewards

**Diagnosis:**
```sql
-- Check actual pending rewards
SELECT get_user_staking_summary('WALLET_ADDRESS');
```

**Solution:**
- Ensure pending rewards >= 0.01 NEFT
- Check frontend is using correct field names (`nft_pending_rewards`)
- Verify service is calling correct RPC function

---

### Issue: Wrong reward rates still appearing

**Diagnosis:**
```sql
-- Check NFT rates
SELECT nft_id, nft_rarity, daily_rate 
FROM staked_nfts 
WHERE daily_rate NOT IN (0.1, 0.4, 1.0, 2.5, 8.0, 30.0);

-- Check token APR
SELECT 
    amount,
    daily_rate,
    ((daily_rate * 365 / amount) * 100)::DECIMAL(10,2) as apr
FROM staked_tokens
WHERE ABS(((daily_rate * 365 / amount) * 100) - 20) > 0.1;
```

**Solution:**
```sql
-- Re-run migration
-- Or manually fix specific records
UPDATE staked_nfts 
SET daily_rate = get_daily_reward_for_rarity(nft_rarity);

UPDATE staked_tokens 
SET daily_rate = (amount * 0.20) / 365.0;
```

---

### Issue: "Function does not exist" errors

**Diagnosis:**
```sql
-- Verify all functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name LIKE '%staking%' 
OR routine_name LIKE '%nft%'
ORDER BY routine_name;
```

**Solution:**
- Re-run the specific FIX file that creates the missing function
- Check for SQL errors in deployment logs

---

## 📞 SUPPORT

### Error Reporting

When reporting issues, include:
1. Error message (exact text)
2. SQL query that caused error
3. Wallet address (if applicable)
4. Timestamp of error
5. Output from diagnostic queries

### Contact

- **Technical Lead:** [Your Name]
- **Database Admin:** [DBA Name]
- **Emergency Contact:** [Emergency Contact]

---

## ✅ DEPLOYMENT COMPLETION CHECKLIST

After completing all steps, verify:

- [ ] All 5 SQL fix files deployed successfully
- [ ] Migration completed with validation passed
- [ ] Backup tables created and populated
- [ ] Cron jobs scheduled and running
- [ ] NFT rates match rarity table (0.1 to 30 NEFT/day)
- [ ] Token rates are 20% APR
- [ ] Pending rewards visible in UI
- [ ] Claim functions working for both NFT and token rewards
- [ ] Frontend integration tested
- [ ] Monitoring dashboards configured
- [ ] Team notified of successful deployment

---

**🎉 CONGRATULATIONS! The staking reward system is now fully fixed and operational.**

**Document Version:** 1.0.0  
**Last Updated:** 2025-01-11  
**Status:** Production Ready
