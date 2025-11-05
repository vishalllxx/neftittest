# 🔧 Fix: Offchain NFTs Not Showing Chain Logo

## 🔍 Root Cause

The distributed NFTs **have chain information in the database**, but the frontend is **not fetching or displaying it**.

### **Problem Flow:**
```
1. NFTs distributed with chain info ✅
   ↓ (assigned_chain, chain_id, chain_contract_address stored)
   
2. Database has chain data ✅
   ↓ (nft_cid_distribution_log table)
   
3. Frontend query MISSING chain fields ❌
   ↓ (only selects: nft_id, rarity, cid, distributed_at)
   
4. UI doesn't have chain data to display ❌
   ↓ (OffchainNFT interface doesn't include chain fields)
```

---

## 📍 Files That Need Updates

### **1. OptimizedCIDPoolBurnService.ts** ← Database Query
- **Location:** `src/services/OptimizedCIDPoolBurnService.ts`
- **Line:** 293-302
- **Issue:** Query doesn't fetch chain fields

### **2. NFTLifecycleService.ts** ← NFT Mapping
- **Location:** `src/services/NFTLifecycleService.ts`  
- **Lines:** 9-22, 191-208
- **Issue:** OffchainNFT interface missing chain fields

---

## ✅ Fix #1: Update Database Query

**File:** `src/services/OptimizedCIDPoolBurnService.ts`

**Find this code (line 293-302):**
```typescript
const { data: distributedNFTs, error } = await this.createClientWithWalletHeader(walletAddress)
  .from('nft_cid_distribution_log')
  .select(`
    nft_id,
    rarity,
    cid,
    distributed_at
  `)
  .eq('wallet_address', walletAddress.toLowerCase())
  .order('distributed_at', { ascending: false });
```

**Replace with:**
```typescript
const { data: distributedNFTs, error } = await this.createClientWithWalletHeader(walletAddress)
  .from('nft_cid_distribution_log')
  .select(`
    nft_id,
    rarity,
    cid,
    distributed_at,
    assigned_chain,
    chain_id,
    chain_contract_address,
    image_url,
    metadata_cid
  `)
  .eq('wallet_address', walletAddress.toLowerCase())
  .order('distributed_at', { ascending: false });
```

**Then update the NFTData return object (line 380-395):**
```typescript
return {
  id: record.nft_id,
  name,
  description,
  image: imageUrl,
  rarity,
  attributes: metadata?.attributes || [
    { trait_type: 'Rarity', value: rarity.charAt(0).toUpperCase() + rarity.slice(1) },
    { trait_type: 'Platform', value: 'NEFTIT' }
  ],
  ipfs_hash: metadataCid,
  metadata_uri: metadataUrl,
  fallback_images: fallbackImages,
  // ✅ Add chain information
  assigned_chain: record.assigned_chain,
  chain_id: record.chain_id,
  chain_contract_address: record.chain_contract_address
};
```

---

## ✅ Fix #2: Update OffchainNFT Interface

**File:** `src/services/NFTLifecycleService.ts`

**Find OffchainNFT interface (line 9-22):**
```typescript
export interface OffchainNFT {
  id: string;
  name: string;
  description?: string;
  image: string;
  rarity: string;
  attributes?: any[];
  ipfs_hash?: string;
  metadata_uri?: string;
  wallet_address: string;
  created_at?: string;
  status: 'offchain' | 'claiming' | 'onchain';
  isStaked?: boolean;
}
```

**Replace with:**
```typescript
export interface OffchainNFT {
  id: string;
  name: string;
  description?: string;
  image: string;
  rarity: string;
  attributes?: any[];
  ipfs_hash?: string;
  metadata_uri?: string;
  wallet_address: string;
  created_at?: string;
  status: 'offchain' | 'claiming' | 'onchain';
  isStaked?: boolean;
  // ✅ Add chain information (same as OnchainNFT)
  assigned_chain?: string;
  chain_id?: number;
  chain_contract_address?: string;
  blockchain?: string;
  chainId?: number;
  chainName?: string;
  chainIconUrl?: string;
}
```

---

## ✅ Fix #3: Update NFT Mapping in loadOffchainNFTs

**File:** `src/services/NFTLifecycleService.ts`

**Find the mapping code (line 191-208):**
```typescript
const offchainNFTs: OffchainNFT[] = nftData
  .filter(nft => !claimedNFTIds.has(nft.id))
  .map(nft => ({
    id: nft.id,
    name: nft.name,
    description: nft.description || `A ${nft.rarity} NFT from the NEFTIT platform`,
    image: nft.image,
    rarity: nft.rarity,
    attributes: nft.attributes || [
      { trait_type: 'Rarity', value: nft.rarity.charAt(0).toUpperCase() + nft.rarity.slice(1) },
      { trait_type: 'Platform', value: 'NEFTIT' }
    ],
    ipfs_hash: nft.ipfs_hash,
    metadata_uri: nft.metadata_uri,
    wallet_address: walletAddress,
    status: 'offchain' as const,
    isStaked: stakedNFTIds.has(nft.id)
  }));
```

**Replace with:**
```typescript
const offchainNFTs: OffchainNFT[] = nftData
  .filter(nft => !claimedNFTIds.has(nft.id))
  .map(nft => ({
    id: nft.id,
    name: nft.name,
    description: nft.description || `A ${nft.rarity} NFT from the NEFTIT platform`,
    image: nft.image,
    rarity: nft.rarity,
    attributes: nft.attributes || [
      { trait_type: 'Rarity', value: nft.rarity.charAt(0).toUpperCase() + nft.rarity.slice(1) },
      { trait_type: 'Platform', value: 'NEFTIT' }
    ],
    ipfs_hash: nft.ipfs_hash,
    metadata_uri: nft.metadata_uri,
    wallet_address: walletAddress,
    status: 'offchain' as const,
    isStaked: stakedNFTIds.has(nft.id),
    // ✅ Add chain information from distributed NFT
    assigned_chain: nft.assigned_chain,
    chain_id: nft.chain_id,
    chain_contract_address: nft.chain_contract_address,
    blockchain: nft.assigned_chain,
    chainId: nft.chain_id,
    // Map chain name from assigned_chain
    chainName: this.getChainName(nft.assigned_chain),
    chainIconUrl: this.getChainIconUrl(nft.assigned_chain)
  }));
```

---

## ✅ Fix #4: Add Helper Methods for Chain Display

**Add these helper methods to NFTLifecycleService class:**

```typescript
/**
 * Get display name for chain
 */
private getChainName(network?: string): string | undefined {
  if (!network) return undefined;
  
  const chainNames: Record<string, string> = {
    'polygon-amoy': 'Polygon Amoy',
    'sepolia': 'Ethereum Sepolia',
    'bsc-testnet': 'BSC Testnet',
    'avalanche-fuji': 'Avalanche Fuji',
    'arbitrum-sepolia': 'Arbitrum Sepolia',
    'optimism-sepolia': 'Optimism Sepolia',
    'base-sepolia': 'Base Sepolia'
  };
  
  return chainNames[network] || network;
}

/**
 * Get chain icon URL
 */
private getChainIconUrl(network?: string): string | undefined {
  if (!network) return undefined;
  
  const chainIcons: Record<string, string> = {
    'polygon-amoy': '/chains/polygon.svg',
    'sepolia': '/chains/ethereum.svg',
    'bsc-testnet': '/chains/bsc.svg',
    'avalanche-fuji': '/chains/avalanche.svg',
    'arbitrum-sepolia': '/chains/arbitrum.svg',
    'optimism-sepolia': '/chains/optimism.svg',
    'base-sepolia': '/chains/base.svg'
  };
  
  return chainIcons[network];
}
```

---

## 🎯 Result After Fixes

Once these changes are applied:

1. **Database Query** ✅ Fetches chain information
2. **NFT Interface** ✅ Includes chain fields
3. **NFT Mapping** ✅ Passes chain data to UI
4. **UI Components** ✅ Can display chain logos

### **UI Will Show:**
```
📦 NEFTIT Common NFT
🔗 Polygon Amoy [Logo]
💎 Rarity: Common
```

---

## 📋 Testing After Fix

1. **Verify Database Has Chain Data:**
```sql
SELECT 
  nft_id,
  rarity,
  assigned_chain,
  chain_id,
  chain_contract_address
FROM nft_cid_distribution_log
WHERE wallet_address = '0x...'
LIMIT 5;
```

2. **Check Frontend Console:**
```
After fix, you should see:
✅ Loaded X offchain NFTs with chain assignments
```

3. **Verify NFT Display:**
- Open Burn page, Stake page, or MyNFTs
- Offchain NFTs should show chain logo
- Hover/inspect to see chain name

---

## 🚀 Quick Summary

**Problem:** Frontend not fetching chain data  
**Solution:** Update 4 code sections  
**Files:** OptimizedCIDPoolBurnService.ts + NFTLifecycleService.ts  
**Result:** Offchain NFTs show chain logos! 🎉
