# 🎨 Burn Chain Breakdown UI - Quick Implementation Guide

## What You'll See

In your burn confirmation modal, when you select mixed NFTs (like 3 offchain + 1 Polygon + 1 BSC), you'll now see:

```
┌─────────────────────────────────────────────────────┐
│ 📊 Burn Breakdown                                    │
│                                                      │
│ 💾 Offchain: 3 NFTs                                 │
│ ⛓️  Onchain:                                         │
│    • Polygon Amoy: 1 NFT                            │
│    • BSC Testnet: 1 NFT                             │
│                                                      │
│ 🔥 Total: 5 NFTs → 1 Platinum                       │
└─────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Steps

### Step 1: Add Helper Functions

Add these functions to `src/pages/Burn.tsx` (around line 400-500, near other helper functions):

```typescript
// Analyze selected NFTs by chain
const analyzeNFTsByChain = () => {
  const offchainNFTs = selectedNFTs.filter(nft => nft.status === 'offchain');
  const onchainNFTs = selectedNFTs.filter(nft => nft.status === 'onchain');
  
  // Group onchain NFTs by chain
  const onchainByChain: Record<string, number> = {};
  onchainNFTs.forEach(nft => {
    const chain = nft.blockchain || nft.claimed_blockchain || nft.chain;
    const chainName = getChainDisplayName(chain);
    
    if (!onchainByChain[chainName]) {
      onchainByChain[chainName] = 0;
    }
    onchainByChain[chainName]++;
  });
  
  return {
    offchainCount: offchainNFTs.length,
    onchainByChain,
    totalOnchain: onchainNFTs.length
  };
};

// Helper to get display name for chain
const getChainDisplayName = (chain?: string): string => {
  if (!chain) return 'Unknown Chain';
  
  const chainMap: Record<string, string> = {
    'polygon-amoy': 'Polygon Amoy',
    'bsc-testnet': 'BSC Testnet',
    'sepolia': 'Ethereum Sepolia',
    'arbitrum-sepolia': 'Arbitrum Sepolia',
    'optimism-sepolia': 'Optimism Sepolia',
    'avalanche-fuji': 'Avalanche Fuji',
    'base-sepolia': 'Base Sepolia'
  };
  
  return chainMap[chain.toLowerCase()] || chain;
};
```

### Step 2: Add UI Component in Modal

Find the burn confirmation modal (search for "You're burning these NFTs to forge something powerful") and add this **after the NFT cards grid** and **before "Burn Rule"**:

```tsx
{/* Burn Breakdown Section */}
{selectedNFTs.length > 0 && (() => {
  const breakdown = analyzeNFTsByChain();
  const hasMultipleTypes = breakdown.offchainCount > 0 && breakdown.totalOnchain > 0;
  const hasMultipleChains = Object.keys(breakdown.onchainByChain).length > 1;
  
  // Only show if there are multiple types or multiple chains
  if (hasMultipleTypes || hasMultipleChains) {
    return (
      <div className="w-full bg-gradient-to-br from-purple-500/10 to-pink-500/10 border border-purple-500/20 rounded-lg p-4 mb-4">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center text-lg">
            📊
          </div>
          <h3 className="text-sm font-semibold text-white">Burn Breakdown</h3>
        </div>
        
        <div className="space-y-2 text-sm">
          {/* Offchain NFTs */}
          {breakdown.offchainCount > 0 && (
            <div className="flex items-center gap-2 text-gray-300">
              <span className="text-purple-400 text-base">💾</span>
              <span className="font-medium">Offchain:</span>
              <span className="text-white">{breakdown.offchainCount} NFT{breakdown.offchainCount !== 1 ? 's' : ''}</span>
            </div>
          )}
          
          {/* Onchain NFTs by Chain */}
          {breakdown.totalOnchain > 0 && (
            <div className="flex items-start gap-2 text-gray-300">
              <span className="text-blue-400 text-base">⛓️</span>
              <div className="flex-1">
                <span className="font-medium">Onchain:</span>
                <div className="ml-6 mt-1 space-y-1">
                  {Object.entries(breakdown.onchainByChain).map(([chain, count]) => (
                    <div key={chain} className="flex items-center gap-2">
                      <span className="text-blue-400">•</span>
                      <span>{chain}:</span>
                      <span className="text-white font-medium">{count} NFT{count !== 1 ? 's' : ''}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
          
          {/* Total Summary */}
          <div className="pt-2 mt-2 border-t border-white/10">
            <div className="flex items-center gap-2 text-white font-medium">
              <span className="text-orange-400 text-base">🔥</span>
              <span>Total:</span>
              <span>{selectedNFTs.length} NFT{selectedNFTs.length !== 1 ? 's' : ''}</span>
              {applicableRule && (
                <>
                  <span className="text-gray-400">→</span>
                  <span className="text-yellow-400">1 {applicableRule.resultingNFT.rarity}</span>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }
  return null;
})()}
```

---

## 🎯 Where to Add in Burn.tsx

**Search for this section** (around line 900-1000):

```tsx
{/* NFT Cards Grid */}
<div className="grid grid-cols-3 gap-4 mb-6">
  {selectedNFTs.map((nft) => (
    // NFT card JSX
  ))}
</div>

{/* ADD THE BREAKDOWN HERE */}

{/* Burn Rule Section */}
<div className="text-center mb-6">
  <h3 className="text-lg font-semibold text-white mb-2">Burn Rule</h3>
  // ...
</div>
```

---

## 📊 Expected Results

### Scenario 1: All Offchain (3 NFTs)
**No breakdown shown** - Simple case

### Scenario 2: All Onchain Same Chain (3 NFTs on Polygon)
**No breakdown shown** - Simple case

### Scenario 3: Mixed (3 offchain + 2 Polygon)
```
📊 Burn Breakdown

💾 Offchain: 3 NFTs
⛓️  Onchain:
   • Polygon Amoy: 2 NFTs

🔥 Total: 5 NFTs → 1 Platinum
```

### Scenario 4: Multi-Chain (2 Polygon + 2 BSC + 1 Arbitrum)
```
📊 Burn Breakdown

⛓️  Onchain:
   • Polygon Amoy: 2 NFTs
   • BSC Testnet: 2 NFTs
   • Arbitrum Sepolia: 1 NFT

🔥 Total: 5 NFTs → 1 Platinum
```

### Scenario 5: Mixed Multi-Chain (Your Screenshot - 3 offchain + 1 Polygon + 1 BSC)
```
📊 Burn Breakdown

💾 Offchain: 3 NFTs
⛓️  Onchain:
   • Polygon Amoy: 1 NFT
   • BSC Testnet: 1 NFT

🔥 Total: 5 NFTs → 1 Platinum
```

---

## ✨ Features

✅ **Smart Display**: Only shows when there are multiple types or chains
✅ **Chain Names**: User-friendly names (not technical IDs)
✅ **Clear Breakdown**: Separates offchain and onchain
✅ **Multi-Chain Support**: Lists each chain with NFT count
✅ **Result Preview**: Shows total and resulting NFT
✅ **Beautiful Styling**: Purple gradient with emojis

---

## 🧪 Test Cases

- [ ] 5 offchain NFTs → No breakdown
- [ ] 5 onchain NFTs (all Polygon) → No breakdown
- [ ] 3 offchain + 2 Polygon → Shows breakdown
- [ ] 2 Polygon + 2 BSC + 1 Arbitrum → Shows breakdown
- [ ] 3 offchain + 1 Polygon + 1 BSC → Shows breakdown
- [ ] Chain names display correctly
- [ ] Counts are accurate
- [ ] Styling looks good

---

## 📝 Summary

**File to Edit:** `src/pages/Burn.tsx`

**Changes:**
1. Add 2 helper functions (`analyzeNFTsByChain`, `getChainDisplayName`)
2. Add breakdown UI component in burn confirmation modal

**Result:** Users will see a beautiful breakdown of their NFT selection by chain, helping them understand multi-chain burns before confirmation!

---

## 🚀 Status

✅ **Documentation Created**
⚠️ **Implementation Needed** - Apply code changes to `Burn.tsx`

The breakdown will automatically show/hide based on the complexity of the burn selection. Simple burns (all same type/chain) won't show it, keeping the UI clean! 🎨
