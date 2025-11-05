# 🚨 FIX CAMPAIGN REWARDS - QUICK ACTION GUIDE

## ⚠️ **THE PROBLEM**

Campaign rewards are not working because **TWO DIFFERENT SYSTEMS** are fighting each other:

1. **OLD System** (campaign_rewards_schema.sql) - Only tracks campaign rewards
2. **NEW System** (comprehensive_balance_aggregation_system.sql) - Tracks ALL rewards

**They're both running and OVERWRITING each other! This causes:**
- ❌ Campaign rewards appear then disappear
- ❌ Balance shows incorrectly
- ❌ Race conditions
- ❌ Database conflicts

---

## ✅ **THE FIX (30 Minutes)**

### **Step 1: Deploy SQL Fix** ⏱️ 5 min

**File:** `database/fix_campaign_reward_conflicts.sql` ✅ **Created for you!**

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy entire contents of `fix_campaign_reward_conflicts.sql`
4. Click "Run"
5. Look for `✅ TEST PASSED!` message

**What this does:**
- ✅ Removes OLD campaign-only trigger
- ✅ Creates NEW trigger using comprehensive sync
- ✅ Fixes RLS policies
- ✅ Tests everything works

---

### **Step 2: Add Referral Rewards** ⏱️ 2 min

**File:** `database/fix_add_referral_to_aggregation.sql` ✅ **Already created!**

1. In Supabase SQL Editor
2. Copy entire contents of `fix_add_referral_to_aggregation.sql`
3. Click "Run"
4. Look for success messages

**What this does:**
- ✅ Adds referral rewards to balance aggregation
- ✅ Creates automatic sync trigger for referrals

---

### **Step 3: Test Campaign Claim** ⏱️ 10 min

1. Open your NEFTIT app
2. Find a campaign with all tasks completed
3. Click "Claim Reward" button
4. Check browser console for logs:

```
✅ Claiming campaign reward for wallet: 0x..., project: ...
✅ Campaign reward claimed successfully
✅ Balance sync triggered successfully
✅ [BalanceContext] Balance updated
```

5. Check MainNav - balance should increase
6. Navigate to Staking page - balance still updated
7. Navigate to Burn page - balance still updated

**If it works:** ✅ **DONE!**

---

## 🔍 **DEBUGGING (If Something Fails)**

### **Issue: "Balance not updating"**

**Check 1:** Verify triggers installed
```sql
SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'campaign_reward_claims';

-- Should show:
-- trigger_sync_balance_after_campaign_claim
```

**Check 2:** Verify sync function exists
```sql
SELECT * FROM aggregate_user_rewards_from_all_sources('YOUR_WALLET');

-- Should return JSON with breakdown
```

**Check 3:** Check browser console
```javascript
// Should see these logs:
🔄 Requesting balance sync for wallet: ...
✅ Balance sync successful
```

---

### **Issue: "RLS policy blocks sync"**

**Fix:**
```sql
-- Run this to fix RLS
DROP POLICY IF EXISTS "service_role_all_access" ON user_balances;

CREATE POLICY "service_role_all_access" ON user_balances
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

---

### **Issue: "Comprehensive function not found"**

**Solution:** Deploy the comprehensive system first!

1. Find: `database/comprehensive_balance_aggregation_system.sql`
2. Deploy in Supabase SQL Editor
3. Then deploy the fix

---

## 📊 **BEFORE vs AFTER**

### **BEFORE (Broken):**
```
Campaign claim
   ↓
OLD trigger adds campaign only (100 NEFT)
   ↓
NEW sync overwrites with all sources (50 NEFT from staking)
   ↓
Result: Shows 50 NEFT (campaign reward LOST!) ❌
```

### **AFTER (Fixed):**
```
Campaign claim
   ↓
NEW trigger syncs ALL sources
   ↓
Aggregates: 100 NEFT (campaign) + 50 NEFT (staking) = 150 NEFT
   ↓
Result: Shows 150 NEFT (all rewards included!) ✅
```

---

## 🎯 **EXPECTED BEHAVIOR**

After the fix, when you claim campaign rewards:

1. ✅ Reward saved to `campaign_reward_claims` table
2. ✅ Trigger fires comprehensive sync
3. ✅ `user_balances` updated with ALL rewards:
   - Campaign rewards
   - Daily claim rewards
   - Achievement rewards
   - Staking rewards
   - Referral rewards (after Step 2)
4. ✅ Supabase real-time fires
5. ✅ UserBalanceContext receives update
6. ✅ MainNav shows new total
7. ✅ All pages show same balance

**No more conflicts! No more race conditions!**

---

## 📋 **CHECKLIST**

- [ ] Step 1: Deploy `fix_campaign_reward_conflicts.sql`
- [ ] Step 2: Deploy `fix_add_referral_to_aggregation.sql`
- [ ] Step 3: Test campaign claim in app
- [ ] Step 4: Verify balance updates everywhere
- [ ] Step 5: Check browser console for errors
- [ ] ✅ **DONE!**

---

## 🚀 **QUICK START (Copy-Paste)**

### **1. In Supabase SQL Editor - Run This First:**

```sql
-- Paste entire contents of:
-- database/fix_campaign_reward_conflicts.sql
```

### **2. In Supabase SQL Editor - Run This Second:**

```sql
-- Paste entire contents of:
-- database/fix_add_referral_to_aggregation.sql
```

### **3. In Browser Console - Test This:**

```javascript
// Complete a campaign and click Claim button
// Watch for these logs:
✅ Campaign reward claimed successfully
✅ Balance sync successful
✅ [BalanceContext] Balance updated
```

---

## 💡 **WHY THIS FIXES IT**

**Root Cause:**
- Campaign schema creates a trigger that ONLY adds campaign rewards
- Comprehensive system tries to aggregate ALL rewards
- They fight each other and create inconsistent state

**The Fix:**
- Remove campaign-only trigger
- Use comprehensive aggregation trigger
- Now ALL rewards are counted together
- No more conflicts!

**Result:**
- Single source of truth
- Consistent balance everywhere
- Real-time updates work
- All reward types included

---

## 🎉 **SUCCESS INDICATORS**

You'll know it's fixed when:

1. ✅ Campaign claim button works
2. ✅ Toast shows "Successfully claimed X NEFT and Y XP"
3. ✅ MainNav balance increases immediately
4. ✅ Balance is same on all pages (Staking, Burn, Activity)
5. ✅ No console errors
6. ✅ Supabase logs show successful sync

**Time to fix: 30 minutes**
**Complexity: Low (just run 2 SQL files!)**
**Impact: HIGH (fixes entire balance system!)**

---

## 📞 **NEED HELP?**

If something doesn't work:

1. Read `CAMPAIGN_REWARDS_DIAGNOSIS.md` for detailed analysis
2. Check browser console for specific error messages
3. Check Supabase logs for database errors
4. Verify both SQL files deployed successfully

**Most common issue:** Comprehensive aggregation system not deployed
**Solution:** Deploy `comprehensive_balance_aggregation_system.sql` first!
