# Burn Chain Breakdown UI - Show NFT Distribution by Chain

## Overview

Add a breakdown section in the burn confirmation modal showing:
- How many offchain NFTs
- How many onchain NFTs per chain (e.g., "2 on Polygon Amoy", "1 on BSC Testnet")

This helps users understand exactly what's being burned before confirmation.

---

## Current UI (Screenshot)

```
┌──────────────────────────────────────────────────────┐
│  You're burning these NFTs to forge something powerful │
│                                                          │
│  Select NFTs you want to burn and confirm the transformation │
│                                                          │
│  [NFT1] [NFT2] [NFT3]                                   │
│  [NFT4] [NFT5]                                          │
│                                                          │
│  Burn Rule                                              │
│  5 Common → 1 Platinum                                  │
│                                                          │
│  [Next →]                                               │
└──────────────────────────────────────────────────────┘
```

---

## Enhanced UI (Proposed)

```
┌──────────────────────────────────────────────────────┐
│  You're burning these NFTs to forge something powerful │
│                                                          │
│  Select NFTs you want to burn and confirm the transformation │
│                                                          │
│  [NFT1] [NFT2] [NFT3]                                   │
│  [NFT4] [NFT5]                                          │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ 📊 Burn Breakdown                               │   │
│  │                                                  │   │
│  │ 💾 Offchain: 3 NFTs                            │   │
│  │ ⛓️  Onchain:                                    │   │
│  │    • Polygon Amoy: 1 NFT                       │   │
│  │    • BSC Testnet: 1 NFT                        │   │
│  │                                                  │   │
│  │ 🔥 Total: 5 NFTs → 1 Platinum                  │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  Burn Rule                                              │
│  5 Common → 1 Platinum                                  │
│                                                          │
│  [Next →]                                               │
└──────────────────────────────────────────────────────┘
```

---

## Implementation

### Location in Code

**File:** `src/pages/Burn.tsx`  
**Component:** Burn confirmation modal (step 1)  
**Section:** Between NFT display and "Burn Rule" section

### Code to Add

**Step 1: Add analysis function**

Find the section where `selectedNFTs` is used and add this helper function:

```typescript
// Analyze selected NFTs by chain (add near other helper functions)
const analyzeNFTsByChain = () => {
  const offchainNFTs = selectedNFTs.filter(nft => nft.status === 'offchain');
  const onchainNFTs = selectedNFTs.filter(nft => nft.status === 'onchain');
  
  // Group onchain NFTs by chain
  const onchainByChain: Record<string, number> = {};
  onchainNFTs.forEach(nft => {
    // Get chain from NFT
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

**Step 2: Use the analysis in the modal**

Find the burn confirmation modal (where NFTs are displayed) and add this section:

```tsx
{/* Burn Breakdown Section - Add after NFT cards display */}
{selectedNFTs.length > 0 && (() => {
  const breakdown = analyzeNFTsByChain();
  const hasMultipleTypes = breakdown.offchainCount > 0 && breakdown.totalOnchain > 0;
  const hasMultipleChains = Object.keys(breakdown.onchainByChain).length > 1;
  
  // Only show if there are multiple types or multiple chains
  if (hasMultipleTypes || hasMultipleChains) {
    return (
      <div className="w-full bg-gradient-to-br from-purple-500/10 to-pink-500/10 border border-purple-500/20 rounded-lg p-4 mb-4">
        <div className="flex items-center gap-2 mb-3">
          <div className="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center">
            📊
          </div>
          <h3 className="text-sm font-semibold text-white">Burn Breakdown</h3>
        </div>
        
        <div className="space-y-2 text-sm">
          {/* Offchain NFTs */}
          {breakdown.offchainCount > 0 && (
            <div className="flex items-center gap-2 text-gray-300">
              <span className="text-purple-400">💾</span>
              <span className="font-medium">Offchain:</span>
              <span className="text-white">{breakdown.offchainCount} NFT{breakdown.offchainCount !== 1 ? 's' : ''}</span>
            </div>
          )}
          
          {/* Onchain NFTs by Chain */}
          {breakdown.totalOnchain > 0 && (
            <>
              <div className="flex items-start gap-2 text-gray-300">
                <span className="text-blue-400">⛓️</span>
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
            </>
          )}
          
          {/* Total Summary */}
          <div className="pt-2 mt-2 border-t border-white/10">
            <div className="flex items-center gap-2 text-white font-medium">
              <span className="text-orange-400">🔥</span>
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

## Visual Examples

### Example 1: Pure Offchain (No breakdown shown)
```
┌────────────────────────────────────────┐
│  [NFT1] [NFT2] [NFT3] [NFT4] [NFT5]   │
│                                         │
│  Burn Rule                              │
│  5 Common → 1 Platinum                  │
└────────────────────────────────────────┘
```
*No breakdown needed - all same type*

### Example 2: Pure Onchain Single Chain (No breakdown shown)
```
┌────────────────────────────────────────┐
│  [NFT1] [NFT2] [NFT3] [NFT4] [NFT5]   │
│                                         │
│  Burn Rule                              │
│  5 Common → 1 Platinum                  │
└────────────────────────────────────────┘
```
*No breakdown needed - all same chain*

### Example 3: Mixed Offchain + Single Chain Onchain
```
┌────────────────────────────────────────┐
│  [NFT1] [NFT2] [NFT3] [NFT4] [NFT5]   │
│                                         │
│  ┌────────────────────────────────┐   │
│  │ 📊 Burn Breakdown               │   │
│  │                                  │   │
│  │ 💾 Offchain: 3 NFTs             │   │
│  │ ⛓️  Onchain:                     │   │
│  │    • Polygon Amoy: 2 NFTs       │   │
│  │                                  │   │
│  │ 🔥 Total: 5 NFTs → 1 Platinum   │   │
│  └────────────────────────────────┘   │
│                                         │
│  Burn Rule                              │
│  5 Common → 1 Platinum                  │
└────────────────────────────────────────┘
```

### Example 4: Multi-Chain Onchain
```
┌────────────────────────────────────────┐
│  [NFT1] [NFT2] [NFT3] [NFT4] [NFT5]   │
│                                         │
│  ┌────────────────────────────────┐   │
│  │ 📊 Burn Breakdown               │   │
│  │                                  │   │
│  │ ⛓️  Onchain:                     │   │
│  │    • Polygon Amoy: 2 NFTs       │   │
│  │    • BSC Testnet: 2 NFTs        │   │
│  │    • Arbitrum Sepolia: 1 NFT    │   │
│  │                                  │   │
│  │ 🔥 Total: 5 NFTs → 1 Platinum   │   │
│  └────────────────────────────────┘   │
│                                         │
│  Burn Rule                              │
│  5 Common → 1 Platinum                  │
└────────────────────────────────────────┘
```

### Example 5: Mixed Multi-Chain (Your Screenshot)
```
┌────────────────────────────────────────┐
│  [NFT1] [NFT2] [NFT3] [NFT4] [NFT5]   │
│                                         │
│  ┌────────────────────────────────┐   │
│  │ 📊 Burn Breakdown               │   │
│  │                                  │   │
│  │ 💾 Offchain: 3 NFTs             │   │
│  │ ⛓️  Onchain:                     │   │
│  │    • Polygon Amoy: 1 NFT        │   │
│  │    • BSC Testnet: 1 NFT         │   │
│  │                                  │   │
│  │ 🔥 Total: 5 NFTs → 1 Platinum   │   │
│  └────────────────────────────────┘   │
│                                         │
│  Burn Rule                              │
│  5 Common → 1 Platinum                  │
└────────────────────────────────────────┘
```

---

## Styling Details

### Colors:
- **Background:** `bg-gradient-to-br from-purple-500/10 to-pink-500/10`
- **Border:** `border border-purple-500/20`
- **Icons:**
  - Offchain (💾): `text-purple-400`
  - Onchain (⛓️): `text-blue-400`
  - Fire (🔥): `text-orange-400`
  - Result: `text-yellow-400`

### Layout:
- **Rounded corners:** `rounded-lg`
- **Padding:** `p-4`
- **Spacing:** `space-y-2` for items
- **Text sizes:**
  - Title: `text-sm font-semibold`
  - Items: `text-sm`
  - Values: `font-medium`

---

## User Benefits

✅ **Clear Understanding**: Users see exactly what's being burned
✅ **Chain Awareness**: Know which chains will be involved
✅ **Gas Preparation**: Can prepare gas fees for specific chains
✅ **Multi-Chain Transparency**: See cross-chain burn breakdown
✅ **Reduced Surprises**: No unexpected chain switches during burn
✅ **Better Decision Making**: Can adjust selection if needed

---

## Logic

### Show Breakdown When:
1. **Mixed offchain + onchain** (different types)
2. **Multiple onchain chains** (multi-chain burn)

### Hide Breakdown When:
1. **All offchain** (simple case)
2. **All onchain on same chain** (simple case)

This keeps the UI clean for simple cases while providing detail for complex scenarios.

---

## Testing Checklist

- [ ] Pure offchain (3 NFTs) → No breakdown
- [ ] Pure onchain same chain (3 NFTs) → No breakdown
- [ ] Mixed: 3 offchain + 2 Polygon → Breakdown shows
- [ ] Multi-chain: 2 Polygon + 2 BSC + 1 Arbitrum → Breakdown shows
- [ ] Mixed multi-chain: 2 offchain + 1 Polygon + 1 BSC + 1 Arbitrum → Breakdown shows
- [ ] Single NFT → No breakdown
- [ ] Chain names display correctly
- [ ] Counts are accurate
- [ ] Icons and colors look good
- [ ] Responsive on mobile

---

## File Location

**Add to:** `src/pages/Burn.tsx`

**Section:** Inside the burn confirmation modal (step 1), after the NFT cards display grid and before the "Burn Rule" section.

**Approximate Line:** Around line 900-1000 (in the modal JSX)

---

## Summary

This enhancement adds a **smart breakdown panel** that only appears when needed:
- Shows offchain vs onchain split
- Lists onchain NFTs by chain
- Displays total and result NFT
- Uses beautiful gradient styling
- Helps users understand complex multi-chain burns

Perfect for your use case with mixed offchain/onchain NFTs across multiple chains! 🎨✨
