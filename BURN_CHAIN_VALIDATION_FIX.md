# Burn Chain Validation & Balance Check - Complete Fix

## Problem Summary

**Issue:** "Selected NFTs are on different chains: polygon-amoy, bsc-testnet. Please select NFTs from the same chain."

**Root Cause:** The burn system was incorrectly validating chains for ALL NFTs including offchain NFTs. Offchain NFTs should burn from database regardless of their "assigned chain" attribute. Only onchain NFTs need chain validation.

---

## ✅ Fixes Implemented

### 1. **useAutoChainSwitch.ts - Chain Validation Logic** ✅ COMPLETED

**File:** `src/hooks/useAutoChainSwitch.ts`

**Changes Made:**
- Updated `switchToNFTsChain()` to separate offchain and onchain NFTs for burn operations
- Offchain NFTs: No chain switching required (burn from database)
- Onchain NFTs: Must be on same chain, switch to that chain
- Mixed burns: Allow mixed offchain/onchain, only validate onchain NFTs

**Key Code:**
```typescript
// Special handling for BURN operations
if (operationType === 'burn') {
  // Separate offchain and onchain NFTs
  const offchainNFTs = nfts.filter(nft => nft.status === 'offchain');
  const onchainNFTs = nfts.filter(nft => nft.status === 'onchain');

  console.log(`🔍 Burn chain validation: ${offchainNFTs.length} offchain, ${onchainNFTs.length} onchain NFTs`);

  // If all NFTs are offchain, no chain switching needed
  if (onchainNFTs.length === 0) {
    console.log('✅ All NFTs are offchain - no chain switching required');
    return { success: true };
  }

  // If we have onchain NFTs, check they're all on the same chain
  if (onchainNFTs.length > 0) {
    const onchainChains = onchainNFTs.map(nft => getChainFromNFT(nft)).filter(Boolean);
    const uniqueOnchainChains = [...new Set(onchainChains)];

    // Onchain NFTs must all be on the same chain
    if (uniqueOnchainChains.length > 1) {
      return {
        success: false,
        message: `Onchain NFTs are on different chains: ${uniqueOnchainChains.join(', ')}. Please select onchain NFTs from the same chain.`,
      };
    }

    // Switch to the chain for onchain NFTs
    console.log(`🔄 Switching to ${uniqueOnchainChains[0]} for onchain NFT burning...`);
    return await switchToNFTChain(onchainNFTs[0], operationType);
  }

  return { success: true };
}
```

---

### 2. **EnhancedHybridBurnService.ts - Balance Checking** ✅ COMPLETED

**File:** `src/services/EnhancedHybridBurnService.ts`

**Changes Made:**
- Added `checkGasBalance()` method to verify sufficient balance before burning
- Checks user's native token balance (MATIC, BNB, etc.)
- Provides clear error messages with actual balance amounts
- Prevents transaction failures due to insufficient gas

**Key Code:**
```typescript
/**
 * Check if user has sufficient balance for gas fees
 */
private async checkGasBalance(): Promise<{ hasBalance: boolean; balance: string; message: string }> {
  try {
    if (!this.web3 || !this.userAccount) {
      await this.initializeContracts();
    }

    // Get user's native token balance
    const balanceWei = await this.web3.eth.getBalance(this.userAccount);
    const balanceEth = this.web3.utils.fromWei(balanceWei, 'ether');
    
    console.log(`💰 Current balance on ${this.currentChain.name}: ${balanceEth} ${this.currentChain.nativeCurrency.symbol}`);

    // Minimum required balance for gas
    const minRequiredBalance = '0.001';

    const hasBalance = parseFloat(balanceEth) >= parseFloat(minRequiredBalance);
    
    return {
      hasBalance,
      balance: balanceEth,
      message: hasBalance 
        ? `Balance: ${parseFloat(balanceEth).toFixed(4)} ${this.currentChain.nativeCurrency.symbol}`
        : `Insufficient balance for gas fees. You have ${parseFloat(balanceEth).toFixed(4)} ${this.currentChain.nativeCurrency.symbol}, but need at least ${minRequiredBalance} ${this.currentChain.nativeCurrency.symbol}`
    };
  } catch (error) {
    console.error('❌ Error checking gas balance:', error);
    return {
      hasBalance: false,
      balance: '0',
      message: 'Failed to check balance'
    };
  }
}

/**
 * Burn onchain NFTs by transferring to burn address
 */
private async burnOnchainNFTs(onchainNFTs: NFTWithStatus[]): Promise<string[]> {
  console.log(`🔥 Burning ${onchainNFTs.length} onchain NFTs...`);
  
  if (!this.nftContract || !this.web3 || !this.userAccount) {
    await this.initializeContracts();
  }

  // Check gas balance before proceeding
  const balanceCheck = await this.checkGasBalance();
  if (!balanceCheck.hasBalance) {
    throw new Error(`${balanceCheck.message}. Please add funds to your wallet on ${this.currentChain.name}.`);
  }

  console.log(`✅ ${balanceCheck.message}`);

  const burnHashes: string[] = [];
  // ... rest of burn logic
}
```

---

## 📝 Required Manual Changes

### 3. **Burn.tsx - User Feedback Messages** ⚠️ NEEDS MANUAL UPDATE

**File:** `src/pages/Burn.tsx`
**Location:** Around line 522-536 (in `handleBurnNFTs` function)

**Find this code:**
```typescript
      }

      // Auto-switch to the correct chain for selected NFTs
      console.log("🔄 Auto-switching to NFTs' chain for burning...");
      const switchResult = await switchToNFTsChain(selectedNFTs, 'burn');
      
      if (!switchResult.success) {
        // If user cancelled, don't show error
        if (!switchResult.cancelled) {
          toast.error(switchResult.message || "Failed to switch to required chain");
        }
        setBurnProgress(0);
        return;
      }

      // Use the NFT operations hook for burning with optimistic updates
```

**Replace with this code:**
```typescript
      }

      // Analyze selected NFTs for burn strategy
      const offchainNFTs = selectedNFTs.filter(nft => nft.status === 'offchain');
      const onchainNFTs = selectedNFTs.filter(nft => nft.status === 'onchain');
      
      console.log(`📊 Burn analysis: ${offchainNFTs.length} offchain, ${onchainNFTs.length} onchain NFTs`);
      
      // Show appropriate message based on burn type
      if (offchainNFTs.length > 0 && onchainNFTs.length === 0) {
        toast.info(`Burning ${offchainNFTs.length} offchain NFT(s) from database...`, { duration: 3000 });
      } else if (onchainNFTs.length > 0 && offchainNFTs.length === 0) {
        toast.info(`Burning ${onchainNFTs.length} onchain NFT(s). Please confirm transaction in MetaMask...`, { duration: 4000 });
      } else if (offchainNFTs.length > 0 && onchainNFTs.length > 0) {
        toast.info(`Mixed burn: ${offchainNFTs.length} offchain + ${onchainNFTs.length} onchain NFT(s)...`, { duration: 4000 });
      }

      // Auto-switch to the correct chain for onchain NFTs only
      console.log("🔄 Checking chain requirements for burning...");
      const switchResult = await switchToNFTsChain(selectedNFTs, 'burn');
      
      if (!switchResult.success) {
        // If user cancelled, don't show error
        if (!switchResult.cancelled) {
          toast.error(switchResult.message || "Failed to switch to required chain");
        }
        setBurnProgress(0);
        return;
      }
      
      // Additional confirmation for onchain burns
      if (onchainNFTs.length > 0) {
        console.log('⚠️ Onchain burn will require gas fees and MetaMask confirmation');
      }

      // Use the NFT operations hook for burning with optimistic updates
```

**What This Does:**
- Analyzes selected NFTs to determine burn strategy (offchain, onchain, or mixed)
- Shows clear toast messages to user explaining what type of burn is happening
- Provides better context for MetaMask transaction prompts
- Logs helpful debugging information

---

## 🎯 Expected User Experience

### Scenario 1: Pure Offchain Burn (3 Offchain NFTs)
```
✅ Selected: 3 Common offchain NFTs
📊 Analysis: 3 offchain, 0 onchain
🔍 Chain Validation: All offchain - no chain switching required
💬 Toast: "Burning 3 offchain NFT(s) from database..."
🔥 Burns from database
✅ Success: New NFT created from CID pool
```

### Scenario 2: Pure Onchain Burn (3 Onchain NFTs on Polygon)
```
✅ Selected: 3 Common onchain NFTs (all on Polygon Amoy)
📊 Analysis: 0 offchain, 3 onchain
🔍 Chain Validation: All onchain on polygon-amoy
🔄 Switches to Polygon Amoy network
💰 Balance Check: 0.0234 MATIC available (sufficient)
💬 Toast: "Burning 3 onchain NFT(s). Please confirm transaction in MetaMask..."
🦊 MetaMask popup: Confirm burn transaction
🔥 Burns onchain, creates new NFT from CID pool
✅ Success: Transaction hash + new NFT
```

### Scenario 3: Mixed Burn (2 Offchain + 1 Onchain on BSC)
```
✅ Selected: 2 offchain + 1 onchain (BSC Testnet)
📊 Analysis: 2 offchain, 1 onchain
🔍 Chain Validation: Onchain NFT on bsc-testnet
🔄 Switches to BSC Testnet network
💰 Balance Check: 0.0156 BNB available (sufficient)
💬 Toast: "Mixed burn: 2 offchain + 1 onchain NFT(s)..."
🦊 MetaMask popup: Confirm burn transaction for onchain NFT
🔥 Burns 2 from database + 1 onchain
✅ Success: New NFT created from CID pool
```

### Scenario 4: Onchain NFTs on Different Chains (ERROR)
```
❌ Selected: 1 NFT on Polygon + 1 NFT on BSC
📊 Analysis: 0 offchain, 2 onchain
🔍 Chain Validation: Onchain NFTs on polygon-amoy, bsc-testnet
❌ Error: "Onchain NFTs are on different chains: polygon-amoy, bsc-testnet. Please select onchain NFTs from the same chain."
💡 Solution: Deselect NFTs from different chains
```

### Scenario 5: Insufficient Gas Balance (ERROR)
```
✅ Selected: 3 onchain NFTs on Polygon
📊 Analysis: 0 offchain, 3 onchain
🔄 Switches to Polygon Amoy
💰 Balance Check: 0.0003 MATIC (insufficient - need 0.001 MATIC)
❌ Error: "Insufficient balance for gas fees. You have 0.0003 MATIC, but need at least 0.001 MATIC. Please add funds to your wallet on Polygon Amoy Testnet."
💡 Solution: Add MATIC to wallet via faucet
```

---

## 🔧 Technical Implementation Details

### Burn Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│ 1. User selects NFTs (offchain/onchain/mixed)          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Burn.tsx: Analyze selection                          │
│    - Count offchain vs onchain NFTs                     │
│    - Show appropriate toast message                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 3. useAutoChainSwitch: Validate chains                  │
│    - If all offchain → Skip chain switching             │
│    - If onchain → Validate same chain                   │
│    - If mixed → Validate onchain NFTs only              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 4. useNFTOperations: Route to burn service              │
│    - Onchain present → enhancedHybridBurnService        │
│    - Pure offchain → optimizedCIDPoolBurnService        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 5. EnhancedHybridBurnService                            │
│    a. Check gas balance (onchain only)                  │
│    b. Burn offchain NFTs from database                  │
│    c. Burn onchain NFTs on blockchain                   │
│    d. Get result NFT from CID pool                      │
│    e. Log transaction                                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Success: Display result NFT with confetti 🎉         │
└─────────────────────────────────────────────────────────┘
```

### Key Validation Points

1. **Rarity-Based Selection** ✅
   - NFTs selected by rarity (e.g., 3x Common → 1x Rare)
   - Burn rules determine required amounts and result
   - Chain is NOT a factor in selection validation

2. **Chain Validation** ✅
   - **Offchain NFTs**: No chain validation (burn from database)
   - **Onchain NFTs**: Must all be on same chain
   - **Mixed**: Only validate onchain NFTs' chains

3. **Balance Validation** ✅
   - **Offchain-only burns**: No balance check needed
   - **Onchain burns**: Check native token balance ≥ 0.001
   - Clear error with actual balance and chain name

4. **Staking Check** ✅
   - Cannot burn staked NFTs (already implemented)
   - Clear error message with unstake instruction

---

## 🧪 Testing Checklist

### Test Case 1: Pure Offchain Burn
- [ ] Select 3 offchain Common NFTs (different assigned chains OK)
- [ ] Should NOT trigger chain switching
- [ ] Should show "Burning 3 offchain NFT(s) from database..."
- [ ] Should burn successfully without MetaMask
- [ ] Result: 1 Rare NFT created

### Test Case 2: Pure Onchain Burn (Same Chain)
- [ ] Select 3 onchain Common NFTs (all on Polygon Amoy)
- [ ] Should switch to Polygon Amoy
- [ ] Should check MATIC balance
- [ ] Should show "Burning 3 onchain NFT(s). Please confirm transaction in MetaMask..."
- [ ] Should prompt MetaMask signature
- [ ] Result: Transaction hash + 1 Rare NFT created

### Test Case 3: Pure Onchain Burn (Different Chains)
- [ ] Select 1 NFT on Polygon + 1 NFT on BSC
- [ ] Should show error: "Onchain NFTs are on different chains..."
- [ ] Should NOT proceed with burn
- [ ] User must deselect to fix

### Test Case 4: Mixed Burn
- [ ] Select 2 offchain + 1 onchain (BSC)
- [ ] Should switch to BSC Testnet
- [ ] Should show "Mixed burn: 2 offchain + 1 onchain NFT(s)..."
- [ ] Should burn 2 from database + 1 onchain
- [ ] Result: 1 Rare NFT created

### Test Case 5: Insufficient Balance
- [ ] Select 3 onchain NFTs
- [ ] Have < 0.001 native tokens in wallet
- [ ] Should show error with exact balance amount
- [ ] Should NOT proceed with burn
- [ ] User must add funds to fix

### Test Case 6: Staked NFTs
- [ ] Select staked NFTs
- [ ] Should show error: "Cannot burn staked NFTs..."
- [ ] Should NOT proceed with burn
- [ ] User must unstake first

---

## 📊 Summary of Changes

| File | Status | Description |
|------|--------|-------------|
| `useAutoChainSwitch.ts` | ✅ COMPLETED | Separate offchain/onchain validation for burns |
| `EnhancedHybridBurnService.ts` | ✅ COMPLETED | Add balance checking before onchain burns |
| `Burn.tsx` | ⚠️ NEEDS MANUAL UPDATE | Add user feedback messages for burn types |

---

## 🎯 Benefits

1. **✅ No More False Chain Errors**: Offchain NFTs with different "assigned chains" can now be burned together
2. **✅ Clear User Guidance**: Users know exactly what type of burn is happening (offchain, onchain, or mixed)
3. **✅ Prevent Failed Transactions**: Balance checking prevents gas-related transaction failures
4. **✅ Better UX**: Appropriate messages for each burn scenario
5. **✅ Proper Chain Switching**: Only switches chains when actually needed for onchain NFTs
6. **✅ Enhanced Debugging**: Console logs show burn analysis and validation steps

---

## 🚀 Deployment Instructions

1. ✅ **useAutoChainSwitch.ts** - Already updated
2. ✅ **EnhancedHybridBurnService.ts** - Already updated
3. ⚠️ **Burn.tsx** - Apply manual changes from section 3 above
4. 🧪 Test all scenarios from testing checklist
5. ✅ Deploy to production

---

**Status:** 2/3 files completed. Burn.tsx needs manual update (see section 3 above).

**Next Step:** Apply the code changes to `src/pages/Burn.tsx` around line 522-536.
