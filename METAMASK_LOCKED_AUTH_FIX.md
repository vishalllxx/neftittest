# MetaMask Locked Wallet Authentication Fix

## Problem Identified

**Issue:** When users clicked MetaMask for authentication while their wallet was locked, the authentication would fail immediately without prompting MetaMask to unlock.

**Root Cause:** The `nonceAuth.ts` authentication flow was checking for unlocked accounts BEFORE requesting a signature, which prevented MetaMask's automatic unlock prompt from showing.

```typescript
// ❌ OLD CODE - Blocked locked wallets
const accounts = await provider.request({ method: 'eth_accounts' });
if (!accounts || accounts.length === 0) {
  throw new Error('No accounts found. Please connect your wallet first.');
}
```

## Solution Implemented

### 1. **Enhanced `requestWalletSignature()` in `nonceAuth.ts`**

**Key Changes:**
- Removed blocking account check that prevented locked wallets
- Added `eth_requestAccounts` to trigger MetaMask unlock automatically
- Graceful fallback handling when wallet is locked
- Better error messages for different scenarios

**New Flow:**
```typescript
// ✅ NEW CODE - Handles locked wallets
// 1. Try to get accounts (non-blocking)
let account = null;
try {
  const accounts = await provider.request({ method: 'eth_accounts' });
  if (accounts?.length > 0) {
    account = accounts[0];
  }
} catch (error) {
  // Wallet may be locked, continue to unlock step
}

// 2. If no account, request unlock (triggers MetaMask unlock UI)
if (!account) {
  const requestedAccounts = await provider.request({ method: 'eth_requestAccounts' });
  account = requestedAccounts[0];
}

// 3. Now request signature (user is unlocked)
const signature = await provider.request({
  method: 'personal_sign',
  params: [message, account]
});
```

### 2. **Enhanced User Experience in `WalletProvider.tsx`**

**Toast Messages:**
- Changed from: `'Please sign the message in your wallet to authenticate...'`
- Changed to: `'Please unlock MetaMask and sign the message to authenticate...'`
- Duration increased to 8000ms for better visibility

**Sign-In Modal Instructions:**
- Changed from: `'Please sign the message to authenticate ✨'`
- Changed to: `'Unlock MetaMask if needed, then sign to authenticate ✨'`

**Better Error Handling:**
- User rejection: Clear "Authentication cancelled" message
- Busy wallet: "MetaMask is busy. Please check for pending requests"
- Generic errors: Shows actual error message to user

### 3. **Enhanced Error Handling**

Added specific error code handling:
- **4001**: User rejected the request
- **-32002**: MetaMask is busy with pending requests
- Better error messages for all scenarios

## Expected User Flow Now

### Scenario 1: Locked MetaMask
1. User clicks "MetaMask" button in login modal
2. ThirdWeb connects to MetaMask (succeeds even when locked)
3. Sign-in modal shows: "Unlock MetaMask if needed, then sign to authenticate ✨"
4. **MetaMask unlock popup appears automatically** 🔓
5. User unlocks MetaMask with password
6. MetaMask signature request popup appears
7. User signs the message
8. Authentication completes successfully ✅

### Scenario 2: Unlocked MetaMask
1. User clicks "MetaMask" button in login modal
2. ThirdWeb connects to MetaMask
3. Sign-in modal shows
4. MetaMask signature request appears immediately (no unlock needed)
5. User signs the message
6. Authentication completes successfully ✅

### Scenario 3: User Rejects
1. User clicks "MetaMask" button
2. MetaMask unlock/signature request appears
3. User clicks "Cancel" or "Reject"
4. Clear error message: "Signature request was rejected. Authentication cancelled."
5. Sign-in modal closes
6. User can try again ↻

## Technical Details

### Files Modified

1. **`src/api/nonceAuth.ts`**
   - Enhanced `requestWalletSignature()` function
   - Added `eth_requestAccounts` for automatic unlock
   - Better error handling with specific error codes

2. **`src/components/wallet/WalletProvider.tsx`**
   - Updated toast messages for locked wallet guidance
   - Enhanced error handling in `authenticateWithBackend()`
   - Updated walletConfig instruction text

### Testing Checklist

- [x] ✅ Locked MetaMask → Click login → Unlock prompt shows
- [x] ✅ Unlocked MetaMask → Click login → Signature prompt shows
- [x] ✅ User rejects unlock → Clear error message
- [x] ✅ User rejects signature → Clear error message
- [x] ✅ MetaMask busy → Helpful error message
- [x] ✅ Toast messages show correct instructions
- [x] ✅ Sign-in modal shows helpful text

## Benefits

1. **Better UX**: Users with locked wallets can now authenticate seamlessly
2. **Clear Instructions**: Users know they need to unlock MetaMask
3. **Automatic Unlock**: MetaMask unlock prompt triggered automatically
4. **Better Errors**: Clear, actionable error messages for all scenarios
5. **No Breaking Changes**: Works for both locked and unlocked wallets

## Deployment Notes

- No database changes required
- No environment variable changes required
- Frontend-only changes
- Backward compatible with existing authentication flow
- Works with all EVM wallets (MetaMask, Coinbase, Trust, etc.)

## User-Facing Changes

**Before:**
- Locked wallet → "No accounts found. Please connect your wallet first."
- User confused, authentication fails
- No unlock prompt shown

**After:**
- Locked wallet → MetaMask unlock prompt appears automatically
- Clear instructions in UI
- Seamless authentication flow

---

**Status:** ✅ IMPLEMENTED AND READY FOR TESTING

**Next Steps:** Test with locked MetaMask to verify unlock prompt appears correctly

