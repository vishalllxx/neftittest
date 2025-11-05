# 🐛 Critical Bug: Web3 Null After Chain Switch

## Error
```
❌ Failed to initialize Web3: TypeError: Cannot read properties of null (reading 'eth')
    at EnhancedHybridBurnService.initializeWeb3 (EnhancedHybridBurnService.ts:116:39)
```

## Root Cause

When checking balance on multiple chains:
1. Switch to chain → Set `this.web3 = null`
2. Call `initializeContracts()` → Calls `initializeWeb3()`
3. `initializeWeb3()` creates `new Web3(provider)` but provider becomes invalid after chain switch
4. Line 116 tries to use `this.web3.eth` but it's null

## The Fix

**File:** `src/services/EnhancedHybridBurnService.ts`

**Line 91-120 - Replace `initializeWeb3()` with:**

```typescript
private async initializeWeb3(): Promise<void> {
  try {
    // ✅ Use ChainManager's MetaMask provider detection to avoid Phantom
    const provider = chainManager.getMetaMaskProvider();
    
    if (!provider) {
      throw new Error('MetaMask not available');
    }
    
    console.log('✅ Using MetaMask provider from ChainManager for NFT burning');
    
    // CREATE NEW WEB3 INSTANCE
    const web3Instance = new Web3(provider);
    
    // VERIFY IT'S WORKING BEFORE ASSIGNING
    if (!web3Instance || !web3Instance.eth) {
      throw new Error('Failed to create Web3 instance');
    }
    
    this.web3 = web3Instance;
    this.selectedProvider = provider;
    
    // Get user account from the selected provider (not window.ethereum)
    const accounts = await provider.request({ method: 'eth_accounts' });
    this.userAccount = accounts[0];
    
    if (!this.userAccount) {
      throw new Error('No account connected');
    }
    
    console.log('👤 Connected account:', this.userAccount.toLowerCase());
    
    // Verify chain ID matches current chain
    const chainId = await this.web3.eth.getChainId();
    console.log('✅ Web3 initialized on chain ID:', chainId);
    
    if (Number(chainId) !== this.currentChain.chainId) {
      console.warn(`⚠️ Chain mismatch: Web3 is on ${chainId}, expected ${this.currentChain.chainId}`);
    }
  } catch (error) {
    console.error('❌ Failed to initialize Web3:', error);
    this.web3 = null; // Ensure it's null on failure
    throw error;
  }
}
```

## Alternative Simpler Fix

**Just add a null check before using web3.eth:**

```typescript
// Line 116 - Add safety check
if (!this.web3 || !this.web3.eth) {
  throw new Error('Web3 instance not properly initialized');
}

const chainId = await this.web3.eth.getChainId();
```

## Better Solution: Don't Null Web3 During Balance Check

**Lines 467-471 - REMOVE the web3 = null lines:**

```typescript
// BEFORE (BUGGY):
await chainManager.switchChain(chainKey);

// Reinitialize for new chain
this.currentChain = chainManager.getCurrentChain();
this.web3 = null;  // ❌ REMOVE THIS
this.nftContract = null;
await this.initializeContracts();

// AFTER (FIXED):
await chainManager.switchChain(chainKey);

// Reinitialize for new chain
this.currentChain = chainManager.getCurrentChain();
// Don't set to null, just reinitialize
await this.initializeContracts();
```

This way, `initializeContracts()` will properly reinitialize web3 without it being null first.

## Apply The Fix

Run this PowerShell to apply the fix:

```powershell
$file = "src\services\EnhancedHybridBurnService.ts"
$content = Get-Content $file -Raw

# Remove the problematic web3 = null lines during chain switching
$content = $content.Replace(
  "          this.currentChain = chainManager.getCurrentChain();`n          this.web3 = null;`n          this.nftContract = null;",
  "          this.currentChain = chainManager.getCurrentChain();`n          this.nftContract = null;"
)

Set-Content $file -Value $content -NoNewline
Write-Host "✅ Fixed web3 null bug - removed unnecessary null assignments"
```

This removes the line that sets `this.web3 = null` which was causing the error.
