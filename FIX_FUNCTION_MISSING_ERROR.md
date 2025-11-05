# 🚨 FIX: Function sync_user_balance_from_all_sources Does Not Exist

## ❌ **ERROR:**
```
ERROR: 42883: function sync_user_balance_from_all_sources(text) does not exist
```

## 🔍 **ROOT CAUSE:**

**The comprehensive balance aggregation system has NOT been deployed yet!**

Your `UserBalanceService.ts` is calling:
```typescript
await client.rpc('sync_user_balance_from_all_sources', {
  user_wallet: walletAddress
});
```

**But this function doesn't exist in your Supabase database!**

---

## ✅ **SOLUTION: Deploy in Correct Order**

You need to deploy the SQL files in the **CORRECT ORDER**:

### **Step 1: Deploy Comprehensive System FIRST** ⏱️ 2 min

**File:** `database/User balance/comprehensive_balance_aggregation_system.sql`

**This creates:**
- ✅ `aggregate_user_rewards_from_all_sources()` - Aggregates all rewards
- ✅ `sync_user_balance_from_all_sources()` - Syncs to user_balances table
- ✅ Triggers for automatic sync
- ✅ Helper functions

**How to deploy:**
1. Open Supabase Dashboard → SQL Editor
2. Open: `database/User balance/comprehensive_balance_aggregation_system.sql`
3. Copy entire contents
4. Paste into SQL Editor
5. Click "Run"
6. Look for success messages

---

### **Step 2: Deploy Campaign Fix SECOND** ⏱️ 2 min

**File:** `database/fix_campaign_reward_conflicts.sql`

**This fixes:**
- ✅ Removes old campaign-only trigger
- ✅ Creates new trigger using comprehensive sync
- ✅ Fixes RLS policies

**How to deploy:**
1. In Supabase SQL Editor
2. Open: `database/fix_campaign_reward_conflicts.sql`
3. Copy entire contents
4. Paste into SQL Editor
5. Click "Run"
6. Look for `✅ TEST PASSED!`

---

### **Step 3: Deploy Referral Fix THIRD** ⏱️ 2 min

**File:** `database/fix_add_referral_to_aggregation.sql`

**This adds:**
- ✅ Referral rewards to aggregation
- ✅ Automatic sync trigger for referrals

**How to deploy:**
1. In Supabase SQL Editor
2. Open: `database/fix_add_referral_to_aggregation.sql`
3. Copy entire contents
4. Paste into SQL Editor
5. Click "Run"

---

## 🧪 **VERIFICATION**

After deploying all three files, verify functions exist:

```sql
-- Check if functions exist
SELECT 
  proname as function_name,
  proargtypes as argument_types,
  prorettype::regtype as return_type
FROM pg_proc 
WHERE proname IN (
  'aggregate_user_rewards_from_all_sources',
  'sync_user_balance_from_all_sources'
);

-- Should show:
-- aggregate_user_rewards_from_all_sources | text | json
-- sync_user_balance_from_all_sources      | text | text
```

Test the functions:

```sql
-- Test aggregation (replace with your wallet)
SELECT * FROM aggregate_user_rewards_from_all_sources('YOUR_WALLET_ADDRESS');

-- Test sync (replace with your wallet)
SELECT sync_user_balance_from_all_sources('YOUR_WALLET_ADDRESS');

-- Check user_balances table
SELECT * FROM user_balances WHERE wallet_address = 'YOUR_WALLET_ADDRESS';
```

---

## 📋 **COMPLETE DEPLOYMENT CHECKLIST**

### **Before You Start:**
- [ ] Open Supabase Dashboard
- [ ] Go to SQL Editor
- [ ] Have all 3 SQL files ready

### **Deploy in Order:**
1. [ ] Deploy `comprehensive_balance_aggregation_system.sql` FIRST
2. [ ] Verify functions created (run verification query)
3. [ ] Deploy `fix_campaign_reward_conflicts.sql` SECOND
4. [ ] Verify test passed
5. [ ] Deploy `fix_add_referral_to_aggregation.sql` THIRD
6. [ ] Verify referral aggregation included

### **Test in App:**
1. [ ] Refresh your NEFTIT app
2. [ ] Complete campaign tasks
3. [ ] Click "Claim Reward"
4. [ ] Check browser console for:
   - ✅ `Balance sync successful`
   - ✅ `[BalanceContext] Balance updated`
5. [ ] Verify balance updates in MainNav
6. [ ] Navigate to other pages - balance consistent

---

## 🔧 **WHY THIS ORDER MATTERS**

### **Order 1 → 2 → 3 is CRITICAL:**

**If you deploy #2 before #1:**
```
❌ fix_campaign_reward_conflicts.sql tries to use:
   sync_user_balance_from_all_sources()
   ↓
❌ Function doesn't exist yet!
   ↓
❌ Trigger creation fails
   ↓
❌ Campaign rewards still broken
```

**If you deploy in correct order:**
```
✅ comprehensive_balance_aggregation_system.sql creates:
   - aggregate_user_rewards_from_all_sources()
   - sync_user_balance_from_all_sources()
   ↓
✅ fix_campaign_reward_conflicts.sql uses:
   - sync_user_balance_from_all_sources() ← Now exists!
   ↓
✅ fix_add_referral_to_aggregation.sql enhances:
   - aggregate_user_rewards_from_all_sources() ← Adds referrals
   ↓
✅ Everything works!
```

---

## 🚨 **IF YOU ALREADY DEPLOYED #2**

No problem! Just deploy #1 now:

```sql
-- Run this in Supabase SQL Editor:
-- Paste entire contents of:
-- database/User balance/comprehensive_balance_aggregation_system.sql
```

Then test:
```sql
-- Verify function exists
SELECT proname FROM pg_proc WHERE proname = 'sync_user_balance_from_all_sources';

-- Test it works
SELECT sync_user_balance_from_all_sources('YOUR_WALLET_ADDRESS');
```

---

## 📊 **WHAT EACH FILE DOES**

### **1. comprehensive_balance_aggregation_system.sql**
**Purpose:** Foundation - creates the aggregation engine

**Creates:**
- `aggregate_user_rewards_from_all_sources()` - Sums all rewards
- `sync_user_balance_from_all_sources()` - Updates user_balances table
- Triggers for automatic sync on reward tables
- Helper functions

**Size:** ~420 lines
**Time:** 2-3 seconds to run

---

### **2. fix_campaign_reward_conflicts.sql**
**Purpose:** Fixes campaign reward conflicts

**Does:**
- Removes old campaign-only trigger
- Creates new trigger using comprehensive sync
- Fixes RLS policies
- Tests everything works

**Size:** ~280 lines
**Time:** 1-2 seconds to run

**Depends on:** File #1 must be deployed first!

---

### **3. fix_add_referral_to_aggregation.sql**
**Purpose:** Adds referral rewards to aggregation

**Does:**
- Enhances `aggregate_user_rewards_from_all_sources()`
- Adds referral_rewards table to aggregation
- Creates trigger for automatic referral sync

**Size:** ~250 lines
**Time:** 1-2 seconds to run

**Depends on:** File #1 must be deployed first!

---

## 🎯 **QUICK FIX (Copy-Paste)**

### **In Supabase SQL Editor:**

**Run This FIRST:**
```sql
-- Paste entire contents of:
-- database/User balance/comprehensive_balance_aggregation_system.sql
-- (Click Run)
```

**Then Run This:**
```sql
-- Paste entire contents of:
-- database/fix_campaign_reward_conflicts.sql
-- (Click Run)
```

**Then Run This:**
```sql
-- Paste entire contents of:
-- database/fix_add_referral_to_aggregation.sql
-- (Click Run)
```

**Verify:**
```sql
-- Check functions exist
SELECT proname FROM pg_proc 
WHERE proname LIKE '%balance%' 
ORDER BY proname;

-- Should show:
-- aggregate_user_rewards_from_all_sources
-- sync_user_balance_from_all_sources
-- sync_user_balance_trigger
-- ... and more
```

---

## 🎉 **SUCCESS INDICATORS**

After deploying all files, you should see:

### **In Supabase:**
- ✅ No SQL errors
- ✅ Functions created successfully
- ✅ Triggers installed
- ✅ Test queries return data

### **In Your App:**
- ✅ Campaign claim works
- ✅ Balance updates immediately
- ✅ No console errors
- ✅ MainNav shows correct balance
- ✅ All pages show same balance

### **In Browser Console:**
```
✅ Claiming campaign reward...
✅ Campaign reward claimed successfully
✅ Requesting balance sync...
✅ Balance sync successful
✅ [BalanceContext] Balance updated: { neft: 150, xp: 100 }
```

---

## 📞 **STILL GETTING ERROR?**

### **Error: "function ... does not exist"**

**Solution:**
1. Check you deployed `comprehensive_balance_aggregation_system.sql`
2. Run verification query:
   ```sql
   SELECT proname FROM pg_proc WHERE proname = 'sync_user_balance_from_all_sources';
   ```
3. If empty, deploy file #1 again
4. Check for SQL errors in deployment

---

### **Error: "permission denied"**

**Solution:**
```sql
-- Grant permissions
GRANT EXECUTE ON FUNCTION sync_user_balance_from_all_sources(TEXT) 
TO authenticated, anon, service_role;

GRANT EXECUTE ON FUNCTION aggregate_user_rewards_from_all_sources(TEXT) 
TO authenticated, anon, service_role;
```

---

### **Error: "table user_balances does not exist"**

**Solution:**
Deploy `campaign_rewards_schema.sql` first to create tables:
```sql
-- This creates user_balances table
-- database/campaign_rewards_schema.sql
```

---

## ⏱️ **TOTAL TIME: 10 Minutes**

1. Deploy file #1: 2 min
2. Deploy file #2: 2 min
3. Deploy file #3: 2 min
4. Verify functions: 2 min
5. Test in app: 2 min

**Total: 10 minutes to complete fix!**

---

## 🚀 **FINAL CHECKLIST**

- [ ] ✅ Deploy `comprehensive_balance_aggregation_system.sql`
- [ ] ✅ Verify functions exist
- [ ] ✅ Deploy `fix_campaign_reward_conflicts.sql`
- [ ] ✅ Verify test passed
- [ ] ✅ Deploy `fix_add_referral_to_aggregation.sql`
- [ ] ✅ Test campaign claim in app
- [ ] ✅ Verify balance updates
- [ ] ✅ Check all pages show same balance
- [ ] 🎉 **DONE!**
