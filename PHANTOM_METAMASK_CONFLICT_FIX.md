# 🔥 PHANTOM + METAMASK CONFLICT FIX

## Root Cause
When **both Phantom and MetaMask** browser extensions are installed, they compete for `window.ethereum`. This caused the app to:
1. ❌ Connect to **Phantom's address** (`0xf765...77aa`) when clicking "MetaMask"
2. ❌ Save wrong address → 406 errors (user not found)
3. ❌ Not recognize MetaMask as "connected" in Edit Profile

---

## The 3 Critical Fixes Applied

### ✅ Fix #1: Main Login (WalletProvider.tsx)
**Problem:** ThirdWeb's `thirdwebAddress` returned Phantom's address instead of MetaMask's.

**Solution:** Lines 127-146 - Directly query MetaMask provider for address
```typescript
// If we have actualMetaMaskProvider, get address from it directly
if (actualMetaMaskProvider && savedWalletType === 'evm') {
  actualMetaMaskProvider.request({ method: 'eth_accounts' })
    .then((accounts: string[]) => {
      const metamaskAddress = accounts[0];
      console.log('✅ Using MetaMask provider address:', metamaskAddress);
      setAddress(metamaskAddress); // Use MetaMask's address, not ThirdWeb's
    });
}
```

---

### ✅ Fix #2: Edit Profile Connection (useConnectProvider.ts)
**Problem:** Edit Profile's MetaMask connection used `window.ethereum` which pointed to Phantom.

**Solution:** Lines 259-291 - Isolate MetaMask from providers array
```typescript
// Isolate MetaMask provider when both wallets are installed
let metamaskProvider = null;

if (window.ethereum?.providers) {
  // Find the actual MetaMask provider
  metamaskProvider = window.ethereum.providers.find(
    (p: any) => p.isMetaMask && !p.isPhantom
  );
} else if (window.ethereum?.isMetaMask && !window.ethereum?.isPhantom) {
  metamaskProvider = window.ethereum;
}

// Use MetaMask provider directly
const accounts = await metamaskProvider.request({ method: 'eth_requestAccounts' });
```

---

### ✅ Fix #3: Edit Profile Display (EditProfile.tsx)
**Problem:** MetaMask stored as `"evm"` but Edit Profile checked for `"metamask"` → didn't show as connected.

**Solution:** Lines 126-132, 153-163, 250-256, 295-307 - Normalize wallet type comparison
```typescript
// Normalize wallet types (evm = metamask)
const normalizedProfileWallet = profile.wallet_type === 'evm' ? 'metamask' : profile.wallet_type;
const normalizedProviderName = providerName === 'evm' ? 'metamask' : providerName;

if (normalizedProfileWallet === normalizedProviderName) {
  return true; // Primary wallet type - shows "Connected (Primary)"
}
```

---

## Testing Instructions

### Test 1: Main Login
1. ✅ **Enable both Phantom AND MetaMask**
2. ✅ Refresh browser (Ctrl + F5)
3. ✅ Click "Connect MetaMask"
4. ✅ Check console logs:
   - Should see: `✅ Using MetaMask provider address: 0x5BEd...5071`
   - Should see: `⚠️ ThirdWeb gave us: 0xf765...77aa` (ignored!)
5. ✅ **Verify:** Your MetaMask data loads perfectly!

### Test 2: Edit Profile Display
1. ✅ Go to Edit Profile page
2. ✅ MetaMask should show:
   - ✅ **"Connected"** status
   - ✅ Your address: `0x5BEd...5071`
   - ✅ **"Primary"** button (can't disconnect)

### Test 3: Edit Profile Connect
1. ✅ Logout and login with different wallet
2. ✅ Go to Edit Profile
3. ✅ Click "Connect" on MetaMask
4. ✅ Check console:
   - Should see: `✅ Edit Profile - MetaMask account received: [correct address]`
5. ✅ **Verify:** Correct MetaMask address is added as secondary wallet

---

## Files Modified

| File | Lines Changed | Purpose |
|------|--------------|---------|
| `WalletProvider.tsx` | 127-146 | Use MetaMask provider directly for address |
| `useConnectProvider.ts` | 259-291 | Isolate MetaMask when connecting in Edit Profile |
| `EditProfile.tsx` | 126-132, 153-163, 250-256, 295-307 | Normalize evm ↔ metamask comparison |

---

## What Changed

### Before ❌
- `window.ethereum` → Phantom (when both installed)
- Login gets `0xf765...77aa` → 406 error
- Edit Profile: MetaMask shows "Not connected"
- Clicking "Connect MetaMask" → connects Phantom

### After ✅
- MetaMask provider isolated from providers array
- Login gets `0x5BEd...5071` → data loads
- Edit Profile: MetaMask shows "Connected (Primary)"
- Both wallets coexist peacefully

---

## Root Cause Summary

**The fundamental issue:** Multiple wallet extensions inject providers into `window.ethereum`. The last-installed or highest-priority wallet overwrites it. Our app was:

1. **Not isolating providers** → used wrong wallet
2. **Storing inconsistent types** → `"evm"` vs `"metamask"`
3. **Not normalizing comparisons** → failed to detect connections

**The fix:** Always isolate the specific provider from the `window.ethereum.providers` array and normalize wallet type strings for comparison.

---

## Date Fixed
2025-10-07

## Status
✅ **RESOLVED** - Both wallets now work correctly when installed together
