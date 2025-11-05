# 🚀 Quick Start Commands - Flexible Chain Distribution

## 📋 Complete Setup Sequence

### **Step 1: Database Setup**

Open Supabase SQL Editor and execute:

```
File: database/setup-chain-distribution-system.sql
```

**What it does:**
- Creates `supported_chains` table
- Creates `distribute_unique_nft_with_chain()` function
- Fixes foreign key constraints
- Sets up helper functions

---

### **Step 2: Clear Old Data**

```bash
node populate-cid-pools-flexible.js clear
```

**Expected Output:**
```
✅ Pools cleared successfully
   - Deleted X NFTs
   - Deleted Y distributions
```

---

### **Step 3: Populate Flexible NFTs**

```bash
node populate-cid-pools-flexible.js populate
```

**What it creates:**
- 25 Common NFTs (flexible)
- 30 Rare NFTs (flexible)
- 30 Legendary NFTs (flexible)
- 10 Platinum NFTs (flexible)
- 5 Silver NFTs (flexible)
- 5 Gold NFTs (flexible)

**Expected Output:**
```
📤 Uploading common NFT #1...
✅ Image uploaded to IPFS
📤 Uploading metadata...
✅ Flexible NFT created
...
✨ Population complete! 105/105 NFTs created
```

---

### **Step 4: Verify Statistics**

```bash
node populate-cid-pools-flexible.js verify
```

**Expected Output:**
```
📈 NFT Pool Statistics:
════════════════════════════════════════════════════════════
COMMON       | unassigned | Total: 25 | Available: 25
RARE         | unassigned | Total: 30 | Available: 30
LEGENDARY    | unassigned | Total: 30 | Available: 30
PLATINUM     | unassigned | Total: 10 | Available: 10
SILVER       | unassigned | Total: 5  | Available: 5
GOLD         | unassigned | Total: 5  | Available: 5
```

---

## 🎯 Distribution Examples

### **Distribute to Polygon Amoy**

**Via HTML Test Interface:**
```
1. Open: test-nft-distribution-with-chains.html
2. Wallet: 0x1234567890123456789012345678901234567890
3. Rarity: Common
4. Chain: Polygon Amoy
5. Click: Distribute NFT
```

**Via Supabase RPC:**
```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1234567890123456789012345678901234567890',
  target_rarity: 'common',
  target_chain: 'polygon-amoy'
});
```

---

### **Distribute to Ethereum Sepolia**

**Via HTML Test Interface:**
```
1. Open: test-nft-distribution-with-chains.html
2. Wallet: 0x9876543210987654321098765432109876543210
3. Rarity: Legendary
4. Chain: Ethereum Sepolia
5. Click: Distribute NFT
```

**Via Supabase RPC:**
```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x9876543210987654321098765432109876543210',
  target_rarity: 'legendary',
  target_chain: 'sepolia'
});
```

---

### **Auto Distribution (Default: Polygon)**

```javascript
const { data, error } = await supabase.rpc('distribute_unique_nft_with_chain', {
  wallet_address: '0x1111111111111111111111111111111111111111',
  target_rarity: 'rare'
  // No target_chain - defaults to polygon-amoy
});
```

---

## 🔄 Common Workflows

### **Daily Workflow**

```bash
# Check current statistics
node populate-cid-pools-flexible.js verify

# If running low on NFTs, add more
node populate-cid-pools-flexible.js populate

# Check again
node populate-cid-pools-flexible.js verify
```

---

### **Reset Workflow**

```bash
# 1. Clear everything
node populate-cid-pools-flexible.js clear

# 2. Repopulate
node populate-cid-pools-flexible.js populate

# 3. Verify
node populate-cid-pools-flexible.js verify
```

---

### **Testing Workflow**

```bash
# 1. Verify NFTs available
node populate-cid-pools-flexible.js verify

# 2. Open test interface
# Open: test-nft-distribution-with-chains.html

# 3. Test Polygon distribution
#    - Select "Polygon Amoy"
#    - Distribute NFT
#    - Verify chain assignment in result

# 4. Test Sepolia distribution
#    - Select "Ethereum Sepolia"
#    - Distribute NFT
#    - Verify chain assignment in result

# 5. Check statistics again
node populate-cid-pools-flexible.js verify
```

---

## 📊 Supported Chains Reference

| Chain | Network ID | Chain ID |
|-------|-----------|----------|
| Polygon Amoy | `polygon-amoy` | 80002 |
| Ethereum Sepolia | `sepolia` | 11155111 |
| BSC Testnet | `bsc-testnet` | 97 |
| Avalanche Fuji | `avalanche-fuji` | 43113 |
| Arbitrum Sepolia | `arbitrum-sepolia` | 421614 |
| Optimism Sepolia | `optimism-sepolia` | 11155420 |
| Base Sepolia | `base-sepolia` | 84532 |

---

## 🛠️ Troubleshooting Commands

### **Check Database Connection**

```javascript
const { data, error } = await supabase.rpc('get_supported_chains');
console.log(data); // Should show all chains
```

---

### **Check NFT Availability**

```sql
-- In Supabase SQL Editor
SELECT 
  rarity,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE is_distributed = false) as available
FROM nft_cid_pools
GROUP BY rarity;
```

---

### **Manually Distribute NFT**

```sql
-- In Supabase SQL Editor
SELECT distribute_unique_nft_with_chain(
  '0x1234567890123456789012345678901234567890',
  'rare',
  'polygon-amoy'
);
```

---

### **Check Distribution History**

```sql
-- In Supabase SQL Editor
SELECT 
  wallet_address,
  rarity,
  assigned_chain,
  distributed_at
FROM nft_cid_distribution_log
ORDER BY distributed_at DESC
LIMIT 10;
```

---

## 📁 File Locations

```
Neftit_Auth_Blockchain_Backend/
├── populate-cid-pools-flexible.js          ← NFT creation script
├── test-nft-distribution-with-chains.html  ← Testing interface
├── FLEXIBLE_CHAIN_DISTRIBUTION_GUIDE.md    ← Full documentation
├── QUICK_START_COMMANDS.md                 ← This file
└── database/
    └── setup-chain-distribution-system.sql ← Database setup
```

---

## ✅ Quick Checklist

**Before Distribution:**
- [ ] Database setup SQL executed
- [ ] Old data cleared
- [ ] Flexible NFTs populated
- [ ] Statistics verified (all unassigned)

**For Polygon Distribution:**
- [ ] Select "polygon-amoy" or "Polygon Amoy"
- [ ] Verify NFT shows `chain_id: 80002`
- [ ] Check NFT contract: `0x5Bb23...`

**For Sepolia Distribution:**
- [ ] Select "sepolia" or "Ethereum Sepolia"
- [ ] Verify NFT shows `chain_id: 11155111`
- [ ] Check NFT contract: `0xedE55...`

---

## 🎉 Success Indicators

**After populate:**
```
✨ Population complete! 105/105 NFTs created
📍 All NFTs are flexible - chains will be assigned during distribution
```

**After distribution:**
```json
{
  "success": true,
  "nft_data": {
    "assigned_chain": "polygon-amoy",
    "chain_id": 80002,
    "chain_contract_address": "0x5Bb23220cC12585264fCd144C448eF222c8572A2"
  }
}
```

**After verify:**
```
TOTALS: 105 NFTs total, X available, Y distributed
```

---

## 🆘 Need Help?

1. Check `FLEXIBLE_CHAIN_DISTRIBUTION_GUIDE.md` for detailed documentation
2. Verify database setup completed successfully
3. Check console logs for error messages
4. Ensure Supabase connection is active
5. Verify Pinata API keys are correct

---

## 🚀 Ready to Start?

```bash
# Just run these commands in order:

# 1. Setup database (in Supabase SQL Editor)
# Execute: database/setup-chain-distribution-system.sql

# 2. Clear and populate
node populate-cid-pools-flexible.js clear
node populate-cid-pools-flexible.js populate

# 3. Test distribution
# Open: test-nft-distribution-with-chains.html

# Done! 🎉
```
