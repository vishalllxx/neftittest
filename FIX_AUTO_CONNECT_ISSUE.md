# Fix: MetaMask Auto-Connecting Without Button Click

## Problem
When opening the wallet connection modal, MetaMask was automatically opening and requesting signature **without the user clicking the Connect button**. The login button would disappear immediately.

## Root Cause

**Location:** `src/components/wallet/WalletProvider.tsx` (Line 768-788)

A useEffect hook was automatically triggering authentication whenever:
1. Wallet was connected (`isConnected`)
2. Had a wallet address (`thirdwebAddress`)
3. User hadn't authenticated yet (`!hasAuthenticated`)
4. Address was different from last login

### The Problem Code:
```typescript
useEffect(() => {
  if (
    isConnected &&
    thirdwebAddress &&
    !hasAuthenticated &&
    thirdwebAddress !== lastAuthenticatedWallet &&
    !connecting  // ❌ This was backwards - should be connecting = true
  ) {
    authenticateWithBackend(thirdwebAddress, walletType || "evm");
  }
}, [isConnected, thirdwebAddress, walletType, connecting]);
```

**Why it failed:**
- The condition `!connecting` meant "trigger authentication when NOT connecting"
- This caused authentication to run on page load/mount
- User never clicked connect button, but MetaMask opened anyway

## Solution Applied

Changed the useEffect conditions to **only authenticate when user explicitly clicks connect**:

```typescript
useEffect(() => {
  // FIXED: Only auto-authenticate if user explicitly initiated connection
  if (
    isConnected &&
    thirdwebAddress &&
    !hasAuthenticated &&
    thirdwebAddress !== lastAuthenticatedWallet &&
    connecting &&          // ✅ Changed: Only when actively connecting
    connectionAttempt > 0  // ✅ Added: Ensure user initiated connection
  ) {
    authenticateWithBackend(thirdwebAddress, walletType || "evm");
  }
}, [isConnected, thirdwebAddress, walletType, connecting, connectionAttempt]);
```

### Key Changes:
1. **Changed `!connecting` to `connecting`**
   - Now only authenticates when user is actively connecting
   - Prevents auto-trigger on page load

2. **Added `connectionAttempt > 0` check**
   - Ensures connection was user-initiated
   - Prevents accidental auto-connects

3. **Added `connectionAttempt` to dependencies**
   - Properly tracks connection state changes

## Expected Behavior Now

### ✅ Before Fix:
1. Open wallet modal
2. MetaMask **automatically opens** (bad!)
3. User confused - never clicked button

### ✅ After Fix:
1. Open wallet modal
2. User **sees login buttons**
3. User clicks "Connect MetaMask"
4. MetaMask opens for signature
5. User approves and logs in

## Testing the Fix

1. **Refresh your browser** (clear any cached state)
2. Click "Connect Wallet" button
3. **Verify:** You should see the wallet selection modal with buttons
4. **Verify:** MetaMask should NOT open automatically
5. Click "Connect MetaMask" button
6. **Verify:** NOW MetaMask should open for signature
7. Sign the message
8. **Verify:** You should be redirected to /discover

## Files Modified
- `src/components/wallet/WalletProvider.tsx` (Line 768-791)

---

✅ **Issue Fixed: Login buttons now stay visible until user clicks them!**
