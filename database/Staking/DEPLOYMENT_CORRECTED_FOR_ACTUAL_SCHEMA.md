# 🚨 DEPLOYMENT GUIDE - CORRECTED FOR YOUR ACTUAL SCHEMA

**Critical: Use ONLY the CORRECTED files, NOT the original ones!**

---

## ✅ What Was Fixed

Your actual database schema uses different column names than I originally assumed:

### Key Differences:

| Table | Original Assumption | Your Actual Schema | Status |
|-------|-------------------|-------------------|--------|
| **staked_nfts** | `daily_rate` | ✅ **`daily_reward`** | Fixed |
| **staked_nfts** | Has `nft_name`, `nft_image` | ❌ **Doesn't have these** | Fixed |
| **staked_nfts** | Missing `last_reward_calculated` | ✅ **Has it** | Added support |
| **staked_nfts** | Missing `transaction_hash` | ✅ **Has it** | Added support |
| **staked_nfts** | Has `created_at` | ❌ **Doesn't have it** | Removed |
| **staked_tokens** | `daily_rate` | ✅ **`daily_reward`** | Fixed |
| **staked_tokens** | Missing `apr_rate` | ✅ **Has it** | Added support |
| **staked_tokens** | Missing `last_reward_calculated` | ✅ **Has it** | Added support |

All CORRECTED files now use **`daily_reward`** everywhere instead of **`daily_rate`**.

---

## 📦 Files You Should Use

### ✅ Use These CORRECTED Files:

1. **FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql** ← Use this
2. **FIX_01B_SERVICE_COMPATIBILITY_CORRECTED.sql** ← Use this
3. **FIX_02_REWARD_GENERATION_CORRECTED.sql** ← Use this
4. ⏳ FIX_03_CLAIM_FUNCTIONS_CORRECTED.sql ← Creating next
5. ⏳ FIX_04_SUMMARY_FUNCTIONS_CORRECTED.sql ← Creating next
6. ⏳ FIX_05_MIGRATION_CORRECTED.sql ← Creating next

### ❌ DON'T Use These Original Files:

- ❌ FIX_01_SCHEMA_AND_FUNCTIONS.sql (wrong column names)
- ❌ FIX_01B_SERVICE_COMPATIBILITY.sql (wrong column names)
- ❌ FIX_02_REWARD_GENERATION.sql (wrong column names)
- ❌ FIX_03_CLAIM_FUNCTIONS.sql (wrong column names)
- ❌ FIX_04_SUMMARY_FUNCTIONS.sql (wrong column names)
- ❌ FIX_05_MIGRATION.sql (wrong column names)

---

## 🚀 Deployment Steps (Updated)

### Step 1: Deploy FIX_01_CORRECTED ✅
```
File: FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql
Time: 5 minutes
Action: Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ Schema Status:
   - All required columns already exist in staked_nfts
   - No schema changes needed

✅ New Functions:
   - get_daily_reward_for_rarity(rarity)
   - stake_nft_with_source(...)

⚠️  IMPORTANT: Functions use daily_reward column (not daily_rate)

🚀 Ready for FIX_02_REWARD_GENERATION_CORRECTED.sql
```

---

### Step 2: Deploy FIX_01B_CORRECTED ✅
```
File: FIX_01B_SERVICE_COMPATIBILITY_CORRECTED.sql
Time: 3 minutes
Action: Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ Created overloaded function:
   - stake_nft_with_source(wallet, id, rarity, source, tx_hash)

✅ Uses actual schema column: daily_reward (not daily_rate)

🎯 Service compatibility ensured!
```

---

### Step 3: Deploy FIX_02_CORRECTED ✅
```
File: FIX_02_REWARD_GENERATION_CORRECTED.sql
Time: 10 minutes
Action: Run in Supabase SQL Editor
```

**Expected Output:**
```
✅ Updated Functions:
   - stake_tokens() now uses 20% APR
   - generate_daily_staking_rewards() with accumulative logic

✅ Cron Job Scheduled:
   - Daily at 00:00 UTC (midnight)

🎯 Reward Rate Verification:
   - 1000 NEFT staked at 20% APR = 0.54794520 NEFT/day

⚠️  IMPORTANT: Functions use daily_reward column (not daily_rate)

🚀 Ready for FIX_03_CLAIM_FUNCTIONS_CORRECTED.sql
```

---

### Step 4-6: Remaining Files
⏳ Creating FIX_03, FIX_04, FIX_05 corrected versions...

---

## 🔍 How to Verify Column Names

Before running any scripts, you can verify your actual schema:

```sql
-- Check staked_nfts columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'staked_nfts' 
ORDER BY ordinal_position;

-- Check staked_tokens columns  
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'staked_tokens' 
ORDER BY ordinal_position;
```

**Key columns to look for:**
- ✅ `daily_reward` (should exist)
- ❌ `daily_rate` (should NOT exist)

---

## ⚠️ Critical Reminders

1. **Only use CORRECTED files**
2. **Deploy in exact order** (FIX_01 → FIX_01B → FIX_02 → ...)
3. **Wait for me to create remaining corrected files** before proceeding to FIX_03+
4. **Verify each step** completes successfully before moving to next

---

## 📊 Current Status

| File | Status | Ready to Deploy |
|------|--------|----------------|
| FIX_01_CORRECTED | ✅ Created | **YES - Run This First** |
| FIX_01B_CORRECTED | ✅ Created | **YES - Run This Second** |
| FIX_02_CORRECTED | ✅ Created | **YES - Run This Third** |
| FIX_03_CORRECTED | ⏳ Creating | Wait |
| FIX_04_CORRECTED | ⏳ Creating | Wait |
| FIX_05_CORRECTED | ⏳ Creating | Wait |

---

**Next Action:** 
1. Run FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql
2. Run FIX_01B_SERVICE_COMPATIBILITY_CORRECTED.sql  
3. Run FIX_02_REWARD_GENERATION_CORRECTED.sql
4. **STOP** and wait for me to create remaining corrected files

Let me know when you're ready, or if you encounter any errors! 🚀
