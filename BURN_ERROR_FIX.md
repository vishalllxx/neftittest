# ✅ Burn Error Fixed: "Some NFTs not found in user collection"

## Error Analysis

**Error Message:**
```
❌ Off-chain burn failed: Error: Some NFTs not found in user collection
```

**What Happened:**
1. User selected 5 NFTs: 1 offchain + 4 onchain (across 3 chains)
2. Multi-chain validation passed ✅
3. System checked `isOnChainAvailable()` → returned `false`
4. Incorrectly fell back to offchain burn for ALL 5 NFTs
5. Failed because 4 onchain NFTs don't exist in offchain database

**Root Cause:**
```typescript
// ❌ OLD LOGIC - WRONG
const isOnChainAvailable = await enhancedHybridBurnService.isOnChainAvailable();

if (onchainNFTs.length > 0 && isOnChainAvailable) {
  // Use hybrid burn
} else {
  // Falls back to offchain burn even if onchain NFTs present!
  result = await optimizedCIDPoolBurnService.burnNFTsOffChain(walletAddress, nftIds);
}
```

**The Problem:** When `isOnChainAvailable` is false but onchain NFTs are selected, it tried to burn onchain NFTs from the offchain database, which fails.

---

## Solution Implemented

**File:** `src/hooks/useNFTOperations.tsx`

**New Logic:**
```typescript
// ✅ NEW LOGIC - CORRECT
// Determine burn strategy based on NFT statuses
const onchainNFTs = nftsToburn.filter(nft => nft.status === 'onchain');
const offchainNFTs = nftsToburn.filter(nft => nft.status === 'offchain');

console.log(`📊 [NFTOperations] Burn analysis: ${offchainNFTs.length} offchain, ${onchainNFTs.length} onchain NFTs`);

// If there are onchain NFTs, check availability and use hybrid burning
if (onchainNFTs.length > 0) {
  // Check onchain availability
  const isOnChainAvailable = await enhancedHybridBurnService.isOnChainAvailable();
  
  if (!isOnChainAvailable) {
    throw new Error('Onchain burning is not available. Please check your wallet connection and try again.');
  }
  
  // Use hybrid burning service
  result = await enhancedHybridBurnService.executeSmartHybridBurn(walletAddress, nftsToburn);
} else {
  // Pure offchain burn
  result = await optimizedCIDPoolBurnService.burnNFTsOffChain(walletAddress, nftIds);
}
```

---

## Key Changes

### Before ❌
1. Check `isOnChainAvailable()` for all burns
2. If false, fall back to offchain burn regardless of NFT types
3. **Result:** Onchain NFTs treated as offchain → Error

### After ✅
1. Check if onchain NFTs are selected
2. If yes, check `isOnChainAvailable()` and throw error if not available
3. If no onchain NFTs, use offchain burn directly
4. **Result:** Clear error message, no incorrect fallback

---

## Expected Behavior Now

### Scenario 1: Pure Offchain (5 offchain NFTs)
```
📊 Burn analysis: 5 offchain, 0 onchain
☁️ Using offchain burn service for 5 offchain NFTs
✅ Success
```

### Scenario 2: Pure Onchain (5 onchain NFTs)
**If wallet connected:**
```
📊 Burn analysis: 0 offchain, 5 onchain
⛓️ Using hybrid burn service for 5 onchain + 0 offchain NFTs
✅ Success
```

**If wallet not connected:**
```
📊 Burn analysis: 0 offchain, 5 onchain
❌ Error: "Onchain burning is not available. Please check your wallet connection and try again."
```

### Scenario 3: Mixed (1 offchain + 4 onchain)
**If wallet connected:**
```
📊 Burn analysis: 1 offchain, 4 onchain
⛓️ Using hybrid burn service for 4 onchain + 1 offchain NFTs
✅ Success
```

**If wallet not connected:**
```
📊 Burn analysis: 1 offchain, 4 onchain
❌ Error: "Onchain burning is not available. Please check your wallet connection and try again."
```

---

## Why `isOnChainAvailable()` Might Return False

The method checks:
```typescript
async isOnChainAvailable(): Promise<boolean> {
  try {
    if (!CONTRACT_ADDRESSES.NFT_CONTRACT) return false;
    await this.initializeContracts();
    return this.nftContract !== null;
  } catch (error) {
    return false;
  }
}
```

**Possible Reasons:**
1. **NFT Contract not configured** - `CONTRACT_ADDRESSES.NFT_CONTRACT` is empty
2. **Wallet not connected** - `initializeContracts()` fails
3. **Wrong network** - MetaMask on different chain than expected
4. **MetaMask locked** - Can't access wallet

---

## User-Friendly Error Messages

### Old Error (Confusing):
```
❌ Some NFTs not found in user collection
```
*User thinks: "But I can see them in my collection!"*

### New Error (Clear):
```
❌ Onchain burning is not available. Please check your wallet connection and try again.
```
*User knows exactly what to do: check wallet*

---

## Testing Checklist

- [ ] Pure offchain burn (5 offchain NFTs) → Works
- [ ] Pure onchain burn with wallet connected → Works
- [ ] Pure onchain burn with wallet disconnected → Clear error
- [ ] Mixed burn with wallet connected → Works
- [ ] Mixed burn with wallet disconnected → Clear error
- [ ] Multi-chain onchain burn → Works (if wallet connected)
- [ ] Error messages are clear and actionable

---

## Additional Notes

### Why This Matters:
- **User Experience:** Clear error messages instead of confusing failures
- **Data Integrity:** Prevents attempting to burn onchain NFTs from wrong storage
- **Multi-Chain Support:** Works correctly with mixed offchain/onchain burns
- **Error Recovery:** Users know exactly what action to take

### Related Features:
- Multi-chain burn support (already implemented)
- Chain validation (already implemented)
- Balance checking (already implemented)
- Burn breakdown UI (documentation ready)

---

## Status

✅ **FIXED** - The logic now correctly handles:
- Pure offchain burns
- Pure onchain burns  
- Mixed offchain/onchain burns
- Multi-chain onchain burns
- Clear error messages when wallet not available

**Next Step:** Test with wallet disconnected to verify error message appears correctly.

---

## Summary

**Problem:** System incorrectly tried to burn onchain NFTs from offchain database when wallet was unavailable.

**Solution:** Check for onchain NFTs first, validate wallet availability, throw clear error if not available.

**Result:** Users get actionable error messages and burns only proceed when all requirements are met.
