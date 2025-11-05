# 🎯 Manual UI Integration Required

## Current Status

✅ **Backend:** Multi-chain balance checking is FULLY implemented in `EnhancedHybridBurnService.ts`
✅ **Helper Functions:** Added to `Burn.tsx` (lines 428-467)
❌ **UI Display:** NOT YET INTEGRATED into the burn modal

---

## What You Need To Do

**Open:** `src/pages/Burn.tsx`

**Find:** Line 1198 (search for `</div>` followed by `<div className="w-full flex flex-col items-center mb-6">`)

**The section looks like this:**
```tsx
                ))}
              </div>
              <div className="w-full flex flex-col items-center mb-6">
                <div className="text-base font-sora text-white font-semibold mb-1">Burn Rule</div>
```

**Add THIS CODE between them:**

```tsx
              </div>
              
              {/* Burn Breakdown Section */}
              {selectedNFTs.length > 0 && (() => {
                const breakdown = analyzeNFTsByChain();
                const hasMultipleTypes = breakdown.offchainCount > 0 && breakdown.totalOnchain > 0;
                const hasMultipleChains = Object.keys(breakdown.onchainByChain).length > 1;
                
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
                        {breakdown.offchainCount > 0 && (
                          <div className="flex items-center gap-2 text-gray-300">
                            <span className="text-purple-400 text-base">💾</span>
                            <span className="font-medium">Offchain:</span>
                            <span className="text-white">{breakdown.offchainCount} NFT{breakdown.offchainCount !== 1 ? 's' : ''}</span>
                          </div>
                        )}
                        
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
              
              <div className="w-full flex flex-col items-center mb-6">
```

---

## What This Will Show

When you select **1 offchain + 1 Polygon + 1 BSC + 1 Sepolia**:

```
┌────────────────────────────────────┐
│ 📊 Burn Breakdown                  │
│                                     │
│ 💾 Offchain: 1 NFT                 │
│ ⛓️  Onchain:                        │
│    • Polygon Amoy: 1 NFT           │
│    • BSC Testnet: 1 NFT            │
│    • Ethereum Sepolia: 1 NFT       │
│                                     │
│ 🔥 Total: 4 NFTs → 1 Platinum      │
└────────────────────────────────────┘
```

---

## Already Implemented (No Action Needed)

✅ Backend balance checking on ALL chains before burning
✅ Helper functions `analyzeNFTsByChain()` and `getChainDisplayName()`
✅ Multi-chain burn support in service layer
✅ Error messages listing insufficient balance chains

---

## Summary

**You have everything except the UI display**

1. Open `src/pages/Burn.tsx`
2. Go to line 1198
3. Copy-paste the code block above
4. Save and refresh

**Then you'll see:**
- Burn breakdown panel showing offchain/onchain counts
- Per-chain breakdown for onchain NFTs
- Total summary with result NFT
- Only shows when needed (multi-chain or mixed burns)

The backend already checks balance on all chains and shows clear error messages!
