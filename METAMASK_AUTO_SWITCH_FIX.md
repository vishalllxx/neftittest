# MetaMask Account Auto-Switch Implementation

## Problem Solved
When users changed their MetaMask account, the app did NOT automatically detect the change. Users had to manually refresh the page to see NFTs from the new account.

## Root Cause
The app was missing MetaMask's `accountsChanged` event listener, which is the standard way to detect when users switch accounts in their MetaMask wallet.

## Solution Implemented

### 1. **useAuthState.ts** - Added MetaMask Event Listener
**File:** `src/hooks/useAuthState.ts`

**What was added:**
```typescript
// Listen for MetaMask account changes
window.ethereum.on('accountsChanged', (accounts) => {
  if (accounts.length === 0) {
    // User disconnected wallet
    // Clear authentication
  } else if (accounts[0] !== currentAddress) {
    // User switched to different account
    // Update localStorage with new address
    // Dispatch events to notify components
  }
});
```

**Features:**
- ✅ Detects when user switches MetaMask account
- ✅ Detects when user disconnects wallet
- ✅ Updates localStorage with new wallet address
- ✅ Dispatches `auth-status-changed` event for other components
- ✅ Dispatches custom `wallet-changed` event with new address
- ✅ Proper cleanup on component unmount

### 2. **NFTContext.tsx** - React to Wallet Changes
**File:** `src/contexts/NFTContext.tsx`

**What was added:**
```typescript
// Listen for wallet changes
useEffect(() => {
  const handleWalletChange = (event: CustomEvent) => {
    console.log('Wallet changed, clearing NFT data...');
    
    // Clear all NFT state
    setAllNFTs([]);
    setOffchainNFTs([]);
    setOnchainNFTs([]);
    setIsInitialized(false);
    setCacheExpiry(null);
    
    // Auto-reload will trigger from walletAddress dependency
  };

  window.addEventListener('wallet-changed', handleWalletChange);
  return () => window.removeEventListener('wallet-changed', handleWalletChange);
}, []);
```

**Features:**
- ✅ Listens for `wallet-changed` custom event
- ✅ Immediately clears all old NFT data
- ✅ Clears cache to force fresh load
- ✅ Triggers automatic reload of new account's NFTs

### 3. **Additional Improvements**
**File:** `src/contexts/NFTContext.tsx`

**Cache optimization:**
- Reduced cache duration from **10 minutes → 2 minutes** for better auto-refresh
- Added `onchainNotLoaded` check to reload if onchain NFTs incomplete
- Reduced setTimeout delay from **500ms → 100ms** for faster detection
- Added `loadingProgress` to useEffect dependencies

## Expected User Flow

### Before Fix ❌
```
User switches MetaMask account
   ↓
App shows OLD account NFTs
   ↓
User confused, manually refreshes page
   ↓
App shows NEW account NFTs
```

### After Fix ✅
```
User switches MetaMask account in extension
   ↓
MetaMask fires 'accountsChanged' event
   ↓
useAuthState detects change
   ↓
Updates localStorage with new address
   ↓
Dispatches 'wallet-changed' event
   ↓
NFTContext clears old NFT data
   ↓
Auto-reload triggers for new wallet
   ↓
Offchain NFTs load (200ms)
   ↓
Onchain NFTs load (5s)
   ↓
✅ NEW account NFTs displayed automatically!
```

## Console Logs to Monitor

When user switches account, you should see:
```
🔄 MetaMask account changed: ['0x...new address']
🔄 Wallet address changed from 0x...old to 0x...new
✅ MetaMask account change listener registered
🔄 [NFTContext] Wallet changed event received: 0x...new
🧹 [NFTContext] Clearing all NFT data for wallet change...
✅ [NFTContext] NFT state cleared, waiting for auto-reload...
🔄 [NFTContext] Auth check: { walletChanged: true }
🔄 [NFTContext] Loading NFT data...
```

## Testing Instructions

1. **Connect MetaMask wallet** to the app
2. **View your NFTs** on Staking/Burn page
3. **Switch to a different account** in MetaMask extension
4. **Watch the console** - You should see the logs above
5. **Verify** - NFTs from new account should load automatically!

## Technical Details

### Event Flow:
1. **MetaMask** → `accountsChanged` event
2. **useAuthState** → Updates localStorage + dispatches events
3. **NFTContext** → Clears state + triggers reload
4. **All Pages** → Show new account's data automatically

### Supported Scenarios:
- ✅ Switching between MetaMask accounts
- ✅ Disconnecting MetaMask wallet
- ✅ Reconnecting with different account
- ✅ Cross-tab synchronization (via storage events)
- ✅ Manual page refresh (existing behavior maintained)

### Files Modified:
1. `src/hooks/useAuthState.ts` - Added MetaMask listener
2. `src/contexts/NFTContext.tsx` - Added wallet-changed listener + optimizations

## Benefits

1. **Better UX** - No manual refresh needed
2. **Real-time Updates** - Instant account switching
3. **Industry Standard** - Matches behavior of OpenSea, Uniswap, etc.
4. **Robust** - Handles disconnections and edge cases
5. **Clean Code** - Centralized event handling

## No Breaking Changes
- ✅ All existing functionality preserved
- ✅ Manual refresh still works
- ✅ Other wallet types unaffected
- ✅ Social login flow unchanged
- ✅ Backward compatible with existing code
