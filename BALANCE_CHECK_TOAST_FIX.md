# 🔔 Add Balance Check Toast Notifications

## Problem
The balance check is running but users can't see it happening. No visual feedback!

---

## Solution
Add toast notifications to show balance checking progress.

---

## File to Edit
`src/services/EnhancedHybridBurnService.ts`

---

## Change 1: Add toast at start of balance check

**Find:** Line 444
```typescript
  ): Promise<{ success: boolean; insufficientChains: string[] }> {
    console.log(`💰 Checking balance on all chains before burning...`);
    
    const insufficientChains: string[] = [];
```

**Replace with:**
```typescript
  ): Promise<{ success: boolean; insufficientChains: string[] }> {
    console.log(`💰 Checking balance on all chains before burning...`);
    const chainCount = Object.keys(nftsByChain).length;
    toast.loading(`Checking gas balance on ${chainCount} chain(s)...`, { id: 'balance-check' });
    
    const insufficientChains: string[] = [];
```

---

## Change 2: Add success/dismiss toast at end

**Find:** Lines 506-509
```typescript
    return {
      success: insufficientChains.length === 0,
      insufficientChains
    };
  }
```

**Replace with:**
```typescript
    // Show success or dismiss loading toast
    if (insufficientChains.length === 0) {
      toast.success('✅ Balance verified on all chains!', { id: 'balance-check' });
    } else {
      toast.dismiss('balance-check');
    }
    
    return {
      success: insufficientChains.length === 0,
      insufficientChains
    };
  }
```

---

## What Users Will See

### When Burning Multi-Chain NFTs:

**Step 1:**
```
🔄 Checking gas balance on 3 chain(s)...
```

**Step 2 (if all good):**
```
✅ Balance verified on all chains!
```

**Step 3 (if insufficient):**
```
❌ Insufficient gas balance on: BSC Testnet (need tBNB), 
   Arbitrum Sepolia (need ETH). Please add funds before burning.
```

---

## Already Working

✅ Balance check logic (checkBalanceOnAllChains)
✅ Error throwing if insufficient balance
✅ Multi-chain validation
✅ Toast import already exists

**Only missing:** Visual feedback to user during the check!

---

## Quick Test After Fix

1. Select 1 Polygon + 1 BSC + 1 Sepolia NFT
2. Click "Burn Selected"
3. You should see: "🔄 Checking gas balance on 3 chain(s)..."
4. Then: "✅ Balance verified on all chains!" (or error if insufficient)
5. Then: Burn proceeds

---

## Alternative: Add to specific per-chain checks

If you also want to show WHICH chain is being checked:

**In the loop at line 458, add:**
```typescript
        if (chainManager.getCurrentChain().network !== chainNetwork) {
          console.log(`🔄 Switching to ${chainConfig.name} to check balance...`);
          toast.loading(`Checking ${chainConfig.name}...`, { id: `check-${chainNetwork}` }); // ADD THIS
          const chainKey = getChainKeyByNetwork(chainNetwork);
```

**After balance check at line 480, add:**
```typescript
        } else {
          console.log(`✅ Sufficient balance on ${chainConfig.name}: ${balanceCheck.balance} ${chainConfig.nativeCurrency.symbol}`);
          toast.dismiss(`check-${chainNetwork}`); // ADD THIS
        }
```

This gives more granular feedback per chain.
