# 🎯 COMPLETE ACTUAL SCHEMA ANALYSIS

**Status:** ✅ All schemas collected and analyzed

---

## Your Actual Database Schema

### 1. staked_nfts

```sql
id                      UUID PRIMARY KEY
wallet_address          TEXT NOT NULL
nft_id                  TEXT NOT NULL
nft_rarity              TEXT ✅
daily_reward            NUMERIC(18,8) ✅ (NOT daily_rate!)
staked_at               TIMESTAMP
staking_source          TEXT DEFAULT 'offchain' ✅
transaction_hash        TEXT ✅
last_reward_calculated  TIMESTAMP ✅
total_earned            NUMERIC(18,8)
last_claim              TIMESTAMP
blockchain              TEXT DEFAULT 'polygon' ✅

MISSING: nft_name, nft_image, created_at
```

### 2. staked_tokens

```sql
id                      UUID PRIMARY KEY
wallet_address          TEXT NOT NULL
amount                  NUMERIC(18,8)
apr_rate                NUMERIC(5,2) DEFAULT 20.00 ✅
daily_reward            NUMERIC(18,8) ✅ (NOT daily_rate!)
staked_at               TIMESTAMP
total_earned            NUMERIC(18,8)
last_claim              TIMESTAMP
last_reward_calculated  TIMESTAMP ✅

MISSING: created_at
```

### 3. staking_rewards

```sql
id                  UUID PRIMARY KEY
wallet_address      TEXT NOT NULL
reward_date         DATE DEFAULT CURRENT_DATE
nft_earned_today    NUMERIC(18,8) ✅ (NOT total_nft_earned!)
token_earned_today  NUMERIC(18,8) ✅ (NOT total_token_earned!)
total_earned        NUMERIC(18,8) ✅ (cumulative)
is_claimed          BOOLEAN DEFAULT false ✅ (NOT claimed!)
created_at          TIMESTAMP
last_updated        TIMESTAMP
reward_type         TEXT
reward_amount       NUMERIC(18,8)
source_id           TEXT
blockchain          TEXT DEFAULT 'polygon'

UNIQUE: (wallet_address, reward_date)

MISSING: total_nft_claimed, total_token_claimed, nft_daily_rate, token_daily_rate
```

### 4. user_balances

```sql
id                      UUID PRIMARY KEY
wallet_address          TEXT UNIQUE
total_neft_claimed      NUMERIC(18,8) ✅
total_xp_earned         INTEGER
last_updated            TIMESTAMP
available_neft          NUMERIC(18,8) ✅
current_level           INTEGER DEFAULT 1
staked_neft             NUMERIC(18,8) ✅
total_nft_count         INTEGER
```

---

## Critical Differences from Original Assumptions

| Feature | Assumed | Actual Reality | Impact |
|---------|---------|----------------|--------|
| **NFT reward column** | `daily_rate` | `daily_reward` | High - rename everywhere |
| **Token reward column** | `daily_rate` | `daily_reward` | High - rename everywhere |
| **NFT metadata** | `nft_name`, `nft_image` stored | Not stored in DB | High - remove inserts |
| **Reward tracking** | Separate `total_nft_earned`, `total_nft_claimed` | Combined `nft_earned_today`, `is_claimed` | Critical - logic rewrite |
| **Claim status** | Per-type (NFT/Token) | Per-day (all or nothing) | Critical - logic rewrite |
| **APR field** | Calculated only | Stored as `apr_rate` | Low - can use it |
| **Transaction hash** | Not expected | Exists in schema | Low - bonus feature |

---

## How Rewards Work (Based on Schema)

### Daily Reward Generation Flow:

```
1. Cron runs at midnight
   ↓
2. For each wallet with staked assets:
   - Calculate today's NFT rewards (sum of all daily_reward from staked_nfts)
   - Calculate today's token rewards (sum of all daily_reward from staked_tokens)
   ↓
3. Insert/Update staking_rewards:
   - nft_earned_today = today's NFT total
   - token_earned_today = today's token total
   - total_earned += (nft_earned_today + token_earned_today)
   - is_claimed = false
   - reward_date = CURRENT_DATE
   ↓
4. Users see pending rewards = SUM(nft_earned_today + token_earned_today) WHERE is_claimed = false
```

### Claim Rewards Flow:

```
1. User clicks "Claim Rewards"
   ↓
2. Calculate total claimable:
   - SUM(nft_earned_today + token_earned_today) 
   - FROM staking_rewards 
   - WHERE wallet_address = user AND is_claimed = false
   ↓
3. If claimable > 0:
   - UPDATE user_balances:
     - available_neft += claimable
     - total_neft_claimed += claimable
   ↓
4. Mark as claimed:
   - UPDATE staking_rewards
   - SET is_claimed = true
   - WHERE wallet_address = user AND is_claimed = false
```

### Key Insights:

- ✅ Rewards are tracked PER DAY (not accumulated with separate claimed counters)
- ✅ `is_claimed` is a boolean flag per day (not separate NFT/Token claim tracking)
- ✅ To claim just NFT rewards OR just token rewards = NOT SUPPORTED by schema
- ⚠️ Schema forces "claim all pending rewards" (can't claim NFT separately from tokens)

---

## Schema-Driven Design Decisions

### ✅ What We CAN Do:

1. Generate daily rewards separately for NFTs and tokens
2. Track them in separate columns (`nft_earned_today`, `token_earned_today`)
3. Show users "NFT pending" vs "Token pending" in UI
4. Claim all pending rewards at once

### ❌ What We CANNOT Do (without schema changes):

1. Claim ONLY NFT rewards (leave token rewards pending)
2. Claim ONLY token rewards (leave NFT rewards pending)
3. Track "how much NFT vs Token claimed historically"

### 💡 Workaround for Separate Claim Buttons:

**Option A:** Change UI to "Claim All Rewards" button only

**Option B:** Keep separate buttons but they both claim everything:
```typescript
handleClaimNFTRewards() {
  // Actually claims BOTH NFT and token rewards
  // Just show NFT amount in success message
}

handleClaimTokenRewards() {
  // Actually claims BOTH NFT and token rewards
  // Just show token amount in success message
}
```

**Option C:** Modify schema to support separate claims (would need new columns)

---

## Files to Create/Update

| File | Status | Key Changes |
|------|--------|-------------|
| FIX_01_CORRECTED | ✅ Done | Uses `daily_reward`, no nft_name/image |
| FIX_01B_CORRECTED | ✅ Done | Uses `daily_reward` |
| FIX_02_CORRECTED | ⏳ Rewrite | Use `nft_earned_today`, `token_earned_today` |
| FIX_03_CORRECTED | ⏳ Create | Claim all at once, use `is_claimed` |
| FIX_04_CORRECTED | ⏳ Create | Calculate from `is_claimed = false` rows |
| FIX_05_CORRECTED | ⏳ Create | Update `daily_reward` values |

---

## Deployment Strategy

Given the schema differences, I recommend:

### Phase 1: Core Functions (Do Now)
1. Deploy FIX_01_CORRECTED ✅
2. Deploy FIX_01B_CORRECTED ✅
3. Wait for remaining corrected files

### Phase 2: Reward Logic (After I finish)
4. Deploy FIX_02_CORRECTED (completely rewritten)
5. Deploy FIX_03_CORRECTED (completely rewritten)
6. Deploy FIX_04_CORRECTED (completely rewritten)
7. Deploy FIX_05_CORRECTED (completely rewritten)

### Phase 3: Frontend Update (If needed)
- Update claim button behavior to match schema limitations
- Consider "Claim All Rewards" single button

---

## Next Steps

1. I'll create completely rewritten FIX_02 through FIX_05
2. They'll match your EXACT schema
3. You can deploy all 7 files in order
4. System will work perfectly with your actual database

**Creating corrected files now...** 🚀
