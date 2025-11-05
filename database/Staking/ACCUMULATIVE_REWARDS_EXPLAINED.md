# 🔄 ACCUMULATIVE STAKING REWARDS - HOW IT WORKS

**TL;DR:** Claiming rewards does NOT unstake your assets. Rewards continue accumulating forever until you manually unstake.

---

## 📊 Visual Flow: Stake → Earn → Claim → Earn More

```
┌─────────────────────────────────────────────────────────────────┐
│                    ACCUMULATIVE REWARD CYCLE                     │
└─────────────────────────────────────────────────────────────────┘

Day 1: STAKE GOLD NFT (30 NEFT/day)
├─ Status: ✅ Staked
├─ Database: staked_nfts entry created
├─ Earning: Started
└─ Pending: 0 NEFT

         ↓ (Cron runs at midnight)

Day 2: REWARDS GENERATED
├─ Status: ✅ Still Staked
├─ Database: total_nft_earned = 30 NEFT
├─ Earning: Yes
└─ Pending: 30 NEFT ← Can claim now

         ↓ (User claims)

Day 2: CLAIM 30 NEFT ⭐
├─ Status: ✅ STILL STAKED (Important!)
├─ Database: total_nft_claimed = 30 NEFT
├─ Earning: ✅ YES (Never stopped!)
├─ Pending: 0 NEFT (just claimed)
└─ Balance: +30 NEFT added to wallet

         ↓ (Cron runs at midnight)

Day 3: NEW REWARDS GENERATED ⭐
├─ Status: ✅ Still Staked
├─ Database: total_nft_earned = 60 NEFT (30 old + 30 new)
├─ Database: total_nft_claimed = 30 NEFT (unchanged)
├─ Earning: Yes
└─ Pending: 30 NEFT ← ACCUMULATIVE! Can claim again

         ↓ (User doesn't claim)

Day 4: MORE REWARDS GENERATED ⭐
├─ Status: ✅ Still Staked
├─ Database: total_nft_earned = 90 NEFT (60 old + 30 new)
├─ Database: total_nft_claimed = 30 NEFT (unchanged)
├─ Earning: Yes
└─ Pending: 60 NEFT ← Growing!

         ↓ (User claims again)

Day 4: CLAIM 60 NEFT ⭐
├─ Status: ✅ STILL STAKED
├─ Database: total_nft_claimed = 90 NEFT (30 + 60)
├─ Earning: ✅ YES
├─ Pending: 0 NEFT (just claimed)
└─ Balance: +60 NEFT added to wallet

         ↓ (Cron runs at midnight)

Day 5: NEW REWARDS GENERATED ⭐
├─ Status: ✅ Still Staked
├─ Database: total_nft_earned = 120 NEFT (90 + 30)
├─ Database: total_nft_claimed = 90 NEFT (unchanged)
├─ Earning: Yes
└─ Pending: 30 NEFT ← CONTINUOUS!

... REPEATS FOREVER until you UNSTAKE! ⚡
```

---

## 🎯 Key Concepts

### 1️⃣ Claiming vs. Unstaking

| Action | NFT/Token Status | Rewards Status | Can Claim Again? |
|--------|-----------------|----------------|------------------|
| **CLAIM** | ✅ Stays Staked | ✅ Keeps Earning | ✅ Yes (after more rewards accumulate) |
| **UNSTAKE** | ❌ Removed from staking | ❌ Stops Earning | ❌ No (no longer staked) |

### 2️⃣ Database Tracking

```sql
-- staking_rewards table tracks your totals:

total_nft_earned    -- All rewards ever generated (keeps growing)
total_nft_claimed   -- All rewards you've claimed (only increases when you claim)

-- Pending rewards formula:
pending_rewards = total_nft_earned - total_nft_claimed

-- Example timeline:
Day 1: earned=0,   claimed=0,  pending=0
Day 2: earned=30,  claimed=0,  pending=30   ← Can claim
CLAIM: earned=30,  claimed=30, pending=0    ← Just claimed, NFT STILL STAKED
Day 3: earned=60,  claimed=30, pending=30   ← New rewards! Can claim again
CLAIM: earned=60,  claimed=60, pending=0    ← Claimed again
Day 4: earned=90,  claimed=60, pending=30   ← More rewards! Repeats forever
```

### 3️⃣ Multiple Claims Allowed

You can claim:
- ✅ Daily (if you want)
- ✅ Weekly (let it build up)
- ✅ Monthly (maximize gas efficiency)
- ✅ Any time you want (as long as pending ≥ 0.01 NEFT)

**Every claim is independent. NFT/token stays staked.**

---

## 📈 Real User Example

**User stakes:**
- 1 Gold NFT (30 NEFT/day)
- 1 Silver NFT (8 NEFT/day)
- 1000 NEFT tokens (0.5479 NEFT/day at 20% APR)

**Total daily rewards:** 38.5479 NEFT/day

**Timeline:**

| Day | Action | NFT Pending | Token Pending | Total Pending | Lifetime Claimed |
|-----|--------|-------------|---------------|---------------|------------------|
| 1 | Staked | 0 | 0 | 0 | 0 |
| 2 | - | 38 | 0.55 | 38.55 | 0 |
| 3 | - | 76 | 1.10 | 77.10 | 0 |
| 4 | **Claim All** | 0 | 0 | 0 | **115.64** |
| 5 | - | 38 | 0.55 | 38.55 | 115.64 |
| 6 | - | 76 | 1.10 | 77.10 | 115.64 |
| 7 | - | 114 | 1.64 | 115.64 | 115.64 |
| 8 | **Claim All** | 0 | 0 | 0 | **231.28** |
| 9 | - | 38 | 0.55 | 38.55 | 231.28 |

**Notice:** After each claim, pending resets to 0, but rewards immediately start accumulating again!

---

## 🔧 Technical Implementation

### Claim Function Logic (Simplified)

```sql
-- When you claim NFT rewards:

1. Calculate: pending = total_nft_earned - total_nft_claimed
2. Validate: pending >= 0.01 NEFT
3. Update: total_nft_claimed = total_nft_earned  ← Mark as claimed
4. Update: user_balances.available_neft += pending  ← Add to wallet
5. ⚠️ IMPORTANT: NFT stays in staked_nfts table  ← Keep earning!

-- Next day when cron runs:
6. NFT still found in staked_nfts  ✅
7. Calculate: new_reward = daily_rate × 1 day
8. Update: total_nft_earned += new_reward  ← Add new rewards
9. Result: pending = total_nft_earned - total_nft_claimed > 0  ✅
```

### Unstake Function Logic (For Comparison)

```sql
-- When you UNSTAKE an NFT:

1. Calculate: pending = total_nft_earned - total_nft_claimed
2. Add pending to staking_rewards (finalize)
3. Update: total_earned in staked_nfts
4. ⚠️ DELETE from staked_nfts table  ← Stop earning!

-- Next day when cron runs:
5. NFT NOT found in staked_nfts  ❌
6. No new rewards generated  ❌
7. Result: Earning stopped permanently  ❌
```

---

## ✅ Verification Queries

Check your accumulative rewards:

```sql
-- See your total earned vs claimed
SELECT 
    wallet_address,
    total_nft_earned,
    total_nft_claimed,
    (total_nft_earned - total_nft_claimed) as nft_pending,
    total_token_earned,
    total_token_claimed,
    (total_token_earned - total_token_claimed) as token_pending
FROM staking_rewards
WHERE wallet_address = 'YOUR_WALLET';

-- Verify NFTs are still staked after claiming
SELECT 
    nft_id,
    nft_name,
    daily_rate,
    total_earned,
    staked_at
FROM staked_nfts
WHERE wallet_address = 'YOUR_WALLET';

-- If this returns rows, your NFTs are STILL STAKED and EARNING! ✅
```

---

## 🎉 Summary

**The Golden Rules:**

1. ✅ **Claiming NEVER unstakes** your assets
2. ✅ **Rewards accumulate FOREVER** until you unstake
3. ✅ **You can claim MULTIPLE TIMES** as rewards build up
4. ✅ **Each claim is INDEPENDENT** of previous claims
5. ✅ **Only UNSTAKING stops** reward generation

**Mental Model:**

Think of staking like a **water tank** that fills up constantly:
- **Staking** = Turn on the tap (water starts flowing)
- **Claiming** = Drain the tank (but tap stays on!)
- **Unstaking** = Turn off the tap (water stops flowing)

The tap (rewards) runs **continuously** from the moment you stake until the moment you unstake, **regardless of how many times you drain (claim) the tank!**

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-11  
**Status:** Production Documentation
