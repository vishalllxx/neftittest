# 🔗 Flexible Chain Distribution System

## Overview

This system implements **flexible chain assignment during distribution** instead of during IPFS upload. This provides maximum flexibility and eliminates foreign key constraint issues.

---

## 🏗️ Architecture

### **Chain Assignment Flow**

```
1. Upload to IPFS
   └─> Image uploaded to Pinata
   └─> Generic metadata created (NO chain info)
   └─> Stored in nft_cid_pools with assigned_chain = NULL

2. Distribution to User
   └─> User/Admin selects target chain (Polygon, Sepolia, etc.)
   └─> distribute_unique_nft_with_chain() function called
   └─> Chain assigned to NFT in database
   └─> NFT marked as distributed with chain info

3. User Claims
   └─> NFT can only be claimed to assigned chain
   └─> Chain info read from distribution log
```

---

## 📦 Setup Instructions

### **Step 1: Run Database Setup**

Execute the SQL setup file in Supabase SQL Editor:

```bash
# File: database/setup-chain-distribution-system.sql
```

This creates:
- ✅ `supported_chains` table with all chain configurations
- ✅ Updated `distribute_unique_nft_with_chain()` function
- ✅ `get_available_cid_counts_by_chain()` function
- ✅ `clear_all_cid_pools()` function
- ✅ Fixed foreign key constraints for cascade delete

### **Step 2: Clear Old Data**

Clear existing NFTs with old chain assignments:

```bash
node populate-cid-pools-flexible.js clear
```

Expected output:
```
✅ Pools cleared successfully
   - Deleted X NFTs
   - Deleted Y distributions
```

### **Step 3: Populate with Flexible NFTs**

Create new NFTs without chain assignments:

```bash
node populate-cid-pools-flexible.js populate
```

This creates:
- 25 Common NFTs (flexible)
- 30 Rare NFTs (flexible)
- 30 Legendary NFTs (flexible)
- 10 Platinum NFTs (flexible)
- 5 Silver NFTs (flexible)
- 5 Gold NFTs (flexible)

All NFTs have:
```javascript
{
  assigned_chain: null,
  chain_id: null,
  chain_contract_address: null,
  can_claim_to_any_chain: true
}
```

### **Step 4: Verify Statistics**

Check NFT availability:

```bash
node populate-cid-pools-flexible.js verify
```

Expected output:
```
📈 NFT Pool Statistics:
════════════════════════════════════════════════════════════
COMMON       | unassigned           | Total: 25 | Available: 25 | Distributed: 0
RARE         | unassigned           | Total: 30 | Available: 30 | Distributed: 0
LEGENDARY    | unassigned           | Total: 30 | Available: 30 | Distributed: 0
...
```

---

## 🎯 Distribution Methods

### **Method 1: Auto Chain Assignment**

Let the system pick the default chain (Polygon Amoy):

```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1234...',
  target_rarity: 'rare',
  target_chain: null  // Auto-assigns to polygon-amoy
});
```

### **Method 2: Specific Chain**

Assign to Polygon Amoy:

```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1234...',
  target_rarity: 'rare',
  target_chain: 'polygon-amoy'  // ✅ Polygon
});
```

Assign to Ethereum Sepolia:

```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1234...',
  target_rarity: 'legendary',
  target_chain: 'sepolia'  // ✅ Sepolia
});
```

### **Method 3: Using Test HTML Interface**

1. Open `test-nft-distribution-with-chains.html` in browser
2. Enter wallet address
3. Select rarity
4. **Select chain from dropdown:**
   - Polygon Amoy
   - Ethereum Sepolia
   - Other chains...
5. Click "Distribute NFT"

---

## 📊 Supported Chains

| Chain | Network ID | Chain ID | NFT Contract |
|-------|-----------|----------|--------------|
| Polygon Amoy | `polygon-amoy` | 80002 | 0x5Bb23...572A2 |
| Ethereum Sepolia | `sepolia` | 11155111 | 0xedE55...9Bd387 |
| BSC Testnet | `bsc-testnet` | 97 | 0xfaAA3...66398b |
| Avalanche Fuji | `avalanche-fuji` | 43113 | 0x7a85E...552F08 |
| Arbitrum Sepolia | `arbitrum-sepolia` | 421614 | 0x71EC8...e21 |
| Optimism Sepolia | `optimism-sepolia` | 11155420 | 0x68C37...1D733 |
| Base Sepolia | `base-sepolia` | 84532 | 0x10ca8...13705 |

---

## 🔧 Database Functions

### **distribute_unique_nft_with_chain**

Distributes NFT and assigns chain:

```sql
SELECT distribute_unique_nft_with_chain(
  '0x1234567890123456789012345678901234567890',  -- wallet
  'rare',                                         -- rarity
  'polygon-amoy'                                  -- chain (optional)
);
```

Returns:
```json
{
  "success": true,
  "nft_data": {
    "id": 123,
    "cid": "QmXXX...",
    "rarity": "rare",
    "assigned_chain": "polygon-amoy",
    "chain_id": 80002,
    "chain_contract_address": "0x5Bb23..."
  }
}
```

### **get_available_cid_counts_by_chain**

Get NFT statistics:

```sql
SELECT * FROM get_available_cid_counts_by_chain();
```

### **clear_all_cid_pools**

Clear all NFTs and distributions:

```sql
SELECT clear_all_cid_pools();
```

---

## ✅ Benefits of This Approach

### **1. Flexibility**
- ✅ Choose chain at distribution time, not upload time
- ✅ Respond to user preferences dynamically
- ✅ Adjust based on chain availability

### **2. Clean Data Management**
- ✅ No foreign key errors when clearing pools
- ✅ Cascade deletes handle distribution logs
- ✅ Easy to reset and repopulate

### **3. Scalability**
- ✅ Add new chains without re-uploading NFTs
- ✅ Update chain configurations in database
- ✅ NFTs remain chain-agnostic until distributed

### **4. User Experience**
- ✅ Users can request specific chains
- ✅ Clear indication of assigned chain
- ✅ Prevents cross-chain confusion

---

## 🚀 Quick Start Commands

```bash
# 1. Setup database (run in Supabase SQL editor)
# Execute: database/setup-chain-distribution-system.sql

# 2. Clear old data
node populate-cid-pools-flexible.js clear

# 3. Create flexible NFTs
node populate-cid-pools-flexible.js populate

# 4. Verify statistics
node populate-cid-pools-flexible.js verify

# 5. Open test interface
# Open: test-nft-distribution-with-chains.html
```

---

## 📝 Test Examples

### **Distribute to Polygon**

```bash
# In browser console or via test interface
const result = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1234567890123456789012345678901234567890',
  target_rarity: 'common',
  target_chain: 'polygon-amoy'
});

console.log(result.data);
// Shows: assigned_chain = 'polygon-amoy', chain_id = 80002
```

### **Distribute to Sepolia**

```bash
const result = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x9876543210987654321098765432109876543210',
  target_rarity: 'legendary',
  target_chain: 'sepolia'
});

console.log(result.data);
// Shows: assigned_chain = 'sepolia', chain_id = 11155111
```

### **Auto Distribution (Default: Polygon)**

```bash
const result = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1111111111111111111111111111111111111111',
  target_rarity: 'rare'
  // No target_chain specified - auto-assigns to polygon-amoy
});
```

---

## 🔄 Migration from Old System

If you have the old `populate-cid-pools-with-chains.js`:

### **Old System:**
- ❌ Chain assigned during IPFS upload
- ❌ Metadata has chain info (immutable)
- ❌ Foreign key errors when clearing
- ❌ Cannot change chain after upload

### **New System:**
- ✅ Chain assigned during distribution
- ✅ Metadata is chain-agnostic
- ✅ Clean cascade deletes
- ✅ Flexible chain selection

### **Migration Steps:**

1. Run `clear` to delete old NFTs
2. Use `populate-cid-pools-flexible.js` instead
3. Update distribution calls to specify chain
4. Test with both Polygon and Sepolia

---

## 🎯 Use Cases

### **Campaign Rewards**
```javascript
// Distribute legendary NFT to winner on Polygon
await distributeNFT(winnerWallet, 'legendary', 'polygon-amoy');
```

### **User Preference**
```javascript
// Let user choose their preferred chain
const userChain = user.preferredChain || 'sepolia';
await distributeNFT(userWallet, 'rare', userChain);
```

### **Load Balancing**
```javascript
// Distribute across chains based on availability
const chain = await getLeastLoadedChain();
await distributeNFT(userWallet, 'common', chain);
```

---

## 🛠️ Troubleshooting

### **Issue: "No available NFTs"**

**Solution:** Check if NFTs exist and are unassigned:

```sql
SELECT rarity, COUNT(*) 
FROM nft_cid_pools 
WHERE is_distributed = false 
GROUP BY rarity;
```

### **Issue: "Invalid chain"**

**Solution:** Verify chain exists in supported_chains:

```sql
SELECT network, chain_name, is_active 
FROM supported_chains;
```

### **Issue: Foreign key error**

**Solution:** Use the clear function instead of direct DELETE:

```sql
SELECT clear_all_cid_pools();
```

---

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `populate-cid-pools-flexible.js` | Creates flexible NFTs (no chain) |
| `setup-chain-distribution-system.sql` | Database setup and functions |
| `test-nft-distribution-with-chains.html` | Testing interface |
| `FLEXIBLE_CHAIN_DISTRIBUTION_GUIDE.md` | This guide |

---

## 🎉 Summary

The flexible chain distribution system provides:

✅ **Maximum flexibility** - Choose chain at distribution time  
✅ **Clean architecture** - No foreign key issues  
✅ **Easy testing** - Clear, populate, verify cycle  
✅ **Scalable** - Add chains without re-uploading  
✅ **User-friendly** - Clear chain assignment process  

**For Polygon & Sepolia distribution:**
1. Run database setup
2. Populate flexible NFTs
3. Distribute with `target_chain: 'polygon-amoy'` or `'sepolia'`
4. Users claim to assigned chain only

Done! 🚀
