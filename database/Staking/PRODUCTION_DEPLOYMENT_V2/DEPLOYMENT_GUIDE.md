# 🚀 PRODUCTION DEPLOYMENT GUIDE

**Copy the following files from parent folder to this folder:**

---

## 📋 Files to Copy

### Required SQL Files (Copy from parent directory):

```
From: /database/Staking/
To:   /database/Staking/PRODUCTION_DEPLOYMENT_V2/

Copy These Files:
1. FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql
2. FIX_01B_SERVICE_COMPATIBILITY_CORRECTED.sql
3. FIX_02_REWARD_GENERATION_FINAL_V2.sql
4. FIX_03_CLAIM_FUNCTIONS_FINAL_V2.sql
5. FIX_04_SUMMARY_FUNCTIONS_FINAL.sql
6. FIX_05_MIGRATION_FINAL.sql
```

---

## ⚡ Quick Deploy

**Run in Supabase SQL Editor in this exact order:**

### Step 1: Core Functions (5 min)
```sql
-- Run: FIX_01_SCHEMA_AND_FUNCTIONS_CORRECTED.sql
```

### Step 2: Compatibility (3 min)
```sql
-- Run: FIX_01B_SERVICE_COMPATIBILITY_CORRECTED.sql
```

### Step 3: Reward Generation (15 min)
```sql
-- Run: FIX_02_REWARD_GENERATION_FINAL_V2.sql
```

### Step 4: Claim Functions (10 min)
```sql
-- Run: FIX_03_CLAIM_FUNCTIONS_FINAL_V2.sql
```

### Step 5: Summary Functions (10 min)
```sql
-- Run: FIX_04_SUMMARY_FUNCTIONS_FINAL.sql
```

### Step 6: Data Migration (15 min)
```sql
-- Run: FIX_05_MIGRATION_FINAL.sql
```

---

## ✅ Verification After Each Step

### After Step 1:
```sql
SELECT get_daily_reward_for_rarity('Gold');  -- Should return 30
```

### After Step 3:
```sql
SELECT * FROM cron.job WHERE jobname LIKE '%staking%';
-- Should show 1 job scheduled
```

### After Step 6:
```sql
-- Check NFT rates
SELECT nft_rarity, MAX(daily_reward) 
FROM staked_nfts 
GROUP BY nft_rarity;

-- Check Token APR
SELECT ((daily_reward * 365 / amount) * 100)::DECIMAL(10,2) as apr
FROM staked_tokens LIMIT 5;
-- Should all be ~20.00
```

---

## 🎯 Success Criteria

- [ ] All 6 files deployed without errors
- [ ] Cron job scheduled (0 0 * * *)
- [ ] NFT rewards correct (0.1 to 30)
- [ ] Token APR = 20%
- [ ] Separate claim buttons work
- [ ] Backup tables created

---

## 📞 Support

If deployment fails at any step:
1. Note which file failed
2. Copy the error message
3. Check parent folder for troubleshooting docs

**Rollback:** Use backup tables created by FIX_05

---

**Total Time:** ~60 minutes  
**Estimated Downtime:** None (backwards compatible)
