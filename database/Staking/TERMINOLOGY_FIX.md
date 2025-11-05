# 🔧 TERMINOLOGY FIX: daily_rate vs daily_reward

**Issue:** Frontend expects `daily_reward` but database functions were returning only `daily_rate`

**Status:** ✅ FIXED

---

## The Problem

### Database Column Name:
```sql
-- In staked_nfts and staked_tokens tables:
daily_rate DECIMAL(18,8)  -- Column stores the value
```

### Frontend Service Expected:
```typescript
// EnhancedStakingService.ts
daily_reward: result.daily_reward  // ❌ Was undefined
```

### Database Functions Returned:
```sql
-- Before fix:
'daily_rate', calculated_daily_rate  // ✅ Had this
'daily_reward', ???                   // ❌ Missing this
```

**Result:** Frontend couldn't read the daily reward value!

---

## The Solution

**Return BOTH field names** for maximum compatibility:

```sql
RETURN json_build_object(
    'success', true,
    'daily_rate', calculated_daily_rate,   -- ✅ Database/technical term
    'daily_reward', calculated_daily_rate, -- ✅ Frontend/user-friendly term
    ...
);
```

This approach:
- ✅ Works with current frontend (expects `daily_reward`)
- ✅ Maintains backward compatibility (if anything uses `daily_rate`)
- ✅ Both fields contain the same value
- ✅ No breaking changes

---

## Files Updated

### 1. FIX_01_SCHEMA_AND_FUNCTIONS.sql
**Function:** `stake_nft_with_source()`

**Before:**
```sql
'daily_rate', calculated_daily_rate
```

**After:**
```sql
'daily_rate', calculated_daily_rate,
'daily_reward', calculated_daily_rate  -- Added
```

---

### 2. FIX_01B_SERVICE_COMPATIBILITY.sql
**Function:** `stake_nft_with_source()` (overloaded version)

**Before:**
```sql
'daily_reward', calculated_daily_rate  -- Only had daily_reward
```

**After:**
```sql
'daily_rate', calculated_daily_rate,   -- Added
'daily_reward', calculated_daily_rate  -- Kept
```

---

### 3. FIX_02_REWARD_GENERATION.sql
**Function:** `stake_tokens()`

**Before:**
```sql
'daily_rate', daily_rate
```

**After:**
```sql
'daily_rate', daily_rate,
'daily_reward', daily_rate  -- Added
```

---

## Response Examples

### NFT Staking Response:
```json
{
  "success": true,
  "message": "NFT staked successfully (Gold rarity, 30.0 NEFT/day)",
  "nft_id": "onchain_123",
  "rarity": "Gold",
  "daily_rate": 30.0,      // ← Database term
  "daily_reward": 30.0,    // ← Frontend term (same value)
  "staking_source": "onchain",
  "blockchain": "NEFTIT"
}
```

### Token Staking Response:
```json
{
  "success": true,
  "message": "Successfully staked 1000 NEFT tokens at 20% APR",
  "staked_amount": 1000.0,
  "daily_rate": 0.54794520,     // ← Database term
  "daily_reward": 0.54794520,   // ← Frontend term (same value)
  "apr": "20%",
  "new_available_balance": 500.0
}
```

---

## Why Both Names?

### Terminology Preferences:

| Context | Preferred Term | Reason |
|---------|----------------|--------|
| **Database Schema** | `daily_rate` | Technical, precise (rate per day) |
| **API Responses** | `daily_reward` | User-friendly (what you earn) |
| **Frontend Display** | `daily_reward` | Clear meaning for users |
| **Documentation** | Both | Depends on audience |

### Real-World Usage:

```typescript
// Frontend code reads:
const reward = result.daily_reward;  // "I get 30 NEFT reward per day"

// Database stores:
daily_rate DECIMAL(18,8);  // "Rate is 30.0 per day"
```

**Both mean the same thing, just different perspectives!**

---

## Verification

After deploying the fixed files, test:

```typescript
// Stake an NFT
const result = await stakeNFT(wallet, nft);

// Both should be defined:
console.log(result.data.daily_rate);    // ✅ 30.0
console.log(result.data.daily_reward);  // ✅ 30.0
```

---

## Summary

**Database column:** `daily_rate` (stays the same)  
**Function returns:** Both `daily_rate` AND `daily_reward` (identical values)  
**Frontend uses:** `daily_reward` (now works correctly)  
**Backward compat:** Anything using `daily_rate` still works  

**Result:** Everyone's happy! ✅

---

**Fixed By:** Terminology alignment update  
**Date:** 2025-01-11  
**Status:** Production Ready  
**Breaking Changes:** None (additive only)
