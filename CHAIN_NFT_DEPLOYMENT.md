# 🚀 Chain-Specific NFT Distribution - Quick Deployment Guide

## Issue Fixed
❌ **Error:** `record "available_cid" has no field "can_claim_to_any_chain"`  
✅ **Solution:** Updated database functions to include chain fields in all responses

---

## Deployment Steps

### Step 1: Deploy Database Migrations (In Order)

Run these SQL files in your Supabase SQL Editor:

#### 1.1 Base System (if not already deployed)
```sql
-- File: database/unique_cid_distribution_system.sql
-- This creates the base nft_cid_pools and distribution tables
```

#### 1.2 Add Chain Support
```sql
-- File: database/add_chain_specific_nft_distribution.sql
-- This adds chain columns and functions
```

#### 1.3 Fix Function Compatibility ⭐ (IMPORTANT)
```sql
-- File: database/fix_chain_distribution_functions.sql
-- This fixes the "can_claim_to_any_chain" error
```

### Step 2: Populate NFT Pool with Chains

```bash
# Navigate to project directory
cd c:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch

# Install dependencies if needed
npm install @supabase/supabase-js axios form-data

# Run population script (adjusted counts: 10 common, 10 rare, 10 legendary, 5 platinum, 2 silver, 2 gold)
node populate-cid-pools-with-chains.js populate
```

**Expected Output:**
```
╔══════════════════════════════════════════════════════════════╗
║   NEFTIT CHAIN-SPECIFIC NFT CID POOL POPULATION SCRIPT      ║
╚══════════════════════════════════════════════════════════════╝
🚀 Starting CID pool population WITH CHAIN ASSIGNMENTS...
🔗 Distributing across 7 chains:
   - Polygon Amoy Testnet (polygon-amoy)
   - Ethereum Sepolia (sepolia)
   - BNB Smart Chain Testnet (bsc-testnet)
   - Avalanche Fuji Testnet (avalanche-fuji)
   - Arbitrum Sepolia (arbitrum-sepolia)
   - Optimism Sepolia (optimism-sepolia)
   - Base Sepolia (base-sepolia)
📊 Total NFTs to create: 39

🎯 Processing common NFTs (10 total)...
📤 Uploading common NFT #1 → Polygon Amoy Testnet...
✅ Image uploaded to IPFS: https://gateway.pinata.cloud/ipfs/...
✅ Complete NFT created - Chain: Polygon Amoy Testnet...
...
```

### Step 3: Verify Population

```bash
node populate-cid-pools-with-chains.js verify
```

**Expected Output:**
```
📊 CID Pool Statistics by Chain:
┌─────────────┬───────────────────────┬───────────┬─────────────┬─────────────────┐
│ Rarity      │ Chain                 │ Total     │ Available   │ Distributed     │
├─────────────┼───────────────────────┼───────────┼─────────────┼─────────────────┤
│ common      │ polygon-amoy          │         2 │           2 │               0 │
│ common      │ sepolia               │         1 │           1 │               0 │
│ common      │ bsc-testnet           │         1 │           1 │               0 │
│ common      │ avalanche-fuji        │         2 │           2 │               0 │
...
```

### Step 4: Test Distribution

Open in browser:
```
file:///c:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/test-nft-distribution-with-chains.html
```

Test:
- ✅ View pool statistics by chain
- ✅ Distribute single NFT (auto-assign or specific chain)
- ✅ Batch distribute across all chains
- ✅ Verify chain assignment in results

---

## NFT Pool Configuration (Current)

Your adjusted counts in `populate-cid-pools-with-chains.js`:

| Rarity | Count | Distribution Strategy |
|--------|-------|----------------------|
| Common | 10 | ~1-2 per chain (7 chains) |
| Rare | 10 | ~1-2 per chain |
| Legendary | 10 | ~1-2 per chain |
| Platinum | 5 | Mix across chains |
| Silver | 2 | 2 chains |
| Gold | 2 | 2 chains |
| **TOTAL** | **39 NFTs** | Evenly distributed |

---

## How It Works

### 1. NFT Upload & Assignment
```javascript
// Each NFT is uploaded to IPFS and assigned to a specific chain
const nft = {
  rarity: 'legendary',
  cid: 'QmXXX...',
  image_url: 'https://gateway.pinata.cloud/ipfs/QmXXX...',
  assigned_chain: 'polygon-amoy',  // ⭐ Pre-assigned
  chain_id: 80002,
  chain_contract_address: '0x5Bb23220cC12585264fCd144C448eF222c8572A2'
};
```

### 2. User Receives NFT (Campaign/Reward)
```javascript
// Backend distributes NFT to user
const result = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x...',
  target_rarity: 'legendary',
  target_chain: null // Auto-assign next available
});
```

### 3. User Claims NFT to Blockchain
```javascript
// Frontend validates chain before claiming
const validation = await supabase.rpc('can_claim_nft_to_chain', {
  nft_cid: 'QmXXX...',
  target_claim_chain: 'polygon-amoy' // Current user's connected chain
});

if (validation.data.can_claim) {
  // Proceed with blockchain claim
} else {
  // Show error: "This NFT can only be claimed to Sepolia"
}
```

### 4. Record Claim Transaction
```javascript
// After successful blockchain mint
await supabase.rpc('record_nft_claim_to_chain', {
  nft_cid: 'QmXXX...',
  claimed_chain: 'polygon-amoy',
  contract_address: '0x5Bb...',
  token_id: '42',
  transaction_hash: '0xabc...'
});
```

---

## Key Database Functions

### ✅ `distribute_unique_nft_with_chain(wallet, rarity, chain?)`
Distribute NFT to user with optional chain specification

### ✅ `get_next_available_cid_by_chain(rarity, chain)`
Get next available NFT for specific chain and rarity

### ✅ `can_claim_nft_to_chain(cid, target_chain)`
Validate if NFT can be claimed to specific blockchain

### ✅ `record_nft_claim_to_chain(cid, chain, contract, tokenId, txHash)`
Record NFT claim transaction

### ✅ `get_available_cid_counts_by_chain()`
Get statistics by chain and rarity

### ✅ `get_chain_distribution_stats()`
Get comprehensive chain distribution summary

---

## Troubleshooting

### ❌ Error: "record has no field can_claim_to_any_chain"
**Solution:** Run `fix_chain_distribution_functions.sql` in Supabase

### ❌ Error: "No available CIDs for rarity"
**Solution:** Run population script or check pool with `verify` command

### ❌ Pinata upload fails
**Solution:** Check API keys in populate script, verify rate limits

### ❌ Chain validation fails
**Solution:** Ensure database migration completed, check assigned_chain values

---

## Frontend Integration Example

### Show Chain Badge on NFT Card
```tsx
{nft.assigned_chain && (
  <div className="chain-badge">
    <img src={`/chain-logos/${getChainIcon(nft.assigned_chain)}`} />
    {getChainName(nft.assigned_chain)}
  </div>
)}
```

### Auto-Switch Network for Claiming
```typescript
async function claimNFT(nft: NFT) {
  const currentChain = await getCurrentChain();
  
  if (currentChain.network !== nft.assigned_chain) {
    // Auto-switch to correct chain
    const targetChain = SUPPORTED_CHAINS.find(
      c => c.network === nft.assigned_chain
    );
    await switchNetwork(targetChain.chainId);
    toast.info(`Switched to ${targetChain.name}`);
  }
  
  // Proceed with claim...
}
```

---

## Success Checklist

- [x] Database migrations deployed (3 files)
- [ ] NFT pool populated with chains
- [ ] Pool verification shows correct distribution
- [ ] Test HTML interface works
- [ ] Single NFT distribution successful
- [ ] Batch distribution successful
- [ ] Chain validation prevents wrong chain claims
- [ ] Frontend shows chain badges
- [ ] Auto network switching implemented

---

## Support

**Files Created:**
- `database/add_chain_specific_nft_distribution.sql` - Base chain system
- `database/fix_chain_distribution_functions.sql` - Fix compatibility
- `populate-cid-pools-with-chains.js` - Population script
- `test-nft-distribution-with-chains.html` - Test interface

**Next Step:** Run `fix_chain_distribution_functions.sql` in Supabase SQL Editor to fix the error! ✅
