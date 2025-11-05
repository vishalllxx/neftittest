# ✅ Manual "Retry Signature" Button - Implementation Complete

## Feature Overview

Added a manual retry button to the sign-in modal that appears when MetaMask signature popup doesn't show up (typically due to popup blockers or hidden windows).

---

## How It Works

### 1. **Auto-Detection (5 seconds)**
```typescript
// Show retry button after 5 seconds if signature not obtained
const retryTimer = setTimeout(() => {
  console.log('⏰ Showing retry button - signature request may be blocked');
  setShowRetryButton(true);
}, 5000);
```

When signature request is sent but not completed within 5 seconds, the retry button automatically appears.

### 2. **Visual UI Changes**

**Initial State (0-5 seconds):**
```
┌──────────────────────────────┐
│     [MetaMask Icon]          │
│       🦊 (spinning)          │
│                              │
│  Sign In with MetaMask       │
│  Unlock MetaMask if needed,  │
│  then sign to authenticate ✨│
│                              │
│         [Cancel]             │
└──────────────────────────────┘
```

**After 5 seconds (if no signature):**
```
┌──────────────────────────────┐
│     [MetaMask Icon]          │
│       🦊 (spinning)          │
│                              │
│  Sign In with MetaMask       │
│  Unlock MetaMask if needed,  │
│  then sign to authenticate ✨│
│                              │
│  ⚠️ Popup blocked? Click     │
│  MetaMask icon in toolbar    │
│  or use retry button below   │
│  ─────────────────────────  │
│                              │
│  [🔄 Retry Signature Request]│
│                              │
│         [Cancel]             │
└──────────────────────────────┘
```

### 3. **Retry Button Functionality**

When user clicks "Retry Signature Request":

```typescript
async function handleRetrySignature() {
  1. Increment retry counter (for tracking)
  2. Hide retry button (prevent spam clicking)
  3. Get current wallet address
  4. Show toast: "Opening MetaMask... Please check for signature request"
  5. Request wallet permissions (brings MetaMask to foreground)
  6. Wait 500ms for popup to appear
  7. Re-trigger authentication flow
  8. If successful: signature obtained, continue to /discover
  9. If failed: show error, re-show retry button
}
```

**Key Features:**
- 🔄 **Permission Request First**: Calls `wallet_requestPermissions` to bring MetaMask popup to foreground
- ⏱️ **Smart Timing**: 500ms delay allows popup to appear
- 🔁 **Retry Counter**: Shows attempt number (e.g., "Attempt 2")
- 🛡️ **Error Handling**: Catches and reports specific errors

---

## User Experience

### Scenario 1: Popup Blocker Active

**Timeline:**
1. **t=0s**: User clicks "MetaMask" login button
2. **t=0.5s**: Sign-in modal appears with spinner
3. **t=1s**: Toast: "Check MetaMask extension for signature request..."
4. **t=5s**: ⚠️ Retry button appears (signature not obtained)
5. **User Action**: Clicks "Retry Signature Request"
6. **t=5.5s**: MetaMask popup appears (permission request triggers it)
7. **t=6s**: User signs message
8. **t=6.5s**: ✅ Authentication complete, redirect to /discover

### Scenario 2: MetaMask Window Hidden

**Timeline:**
1. **t=0s**: User clicks "MetaMask" login button
2. **t=0.5s**: MetaMask popup opens but behind other windows
3. **t=5s**: Retry button appears (user hasn't found popup yet)
4. **User Action**: Clicks "Retry Signature Request"
5. **t=5.5s**: Permission request brings MetaMask window to front
6. **t=6s**: User sees popup and signs
7. **t=6.5s**: ✅ Authentication complete

### Scenario 3: MetaMask Busy

**Timeline:**
1. **t=0s**: User clicks "MetaMask" login button
2. **t=0.5s**: MetaMask already has pending request
3. **t=5s**: Retry button appears
4. **User Action**: Opens MetaMask extension, clears old request
5. **User Action**: Clicks "Retry Signature Request"
6. **t=5.5s**: New signature request appears
7. **t=6s**: User signs
8. **t=6.5s**: ✅ Authentication complete

---

## Technical Implementation

### State Management
```typescript
const [showRetryButton, setShowRetryButton] = useState(false);
const [retryCount, setRetryCount] = useState(0);
```

### Timer Setup
```typescript
// Show retry button after 5 seconds
const retryTimer = setTimeout(() => {
  setShowRetryButton(true);
}, 5000);

// Clear timer if signature obtained
clearTimeout(retryTimer);
```

### Retry Handler
```typescript
const handleRetrySignature = async () => {
  setRetryCount(prev => prev + 1);
  setShowRetryButton(false);
  
  // Request permissions (brings MetaMask to foreground)
  await providerToUse.request({ 
    method: 'wallet_requestPermissions',
    params: [{ eth_accounts: {} }]
  });
  
  // Retry authentication
  await authenticateWithBackend(currentAddress, walletType || "evm");
};
```

### UI Components
```tsx
{/* Retry Button - appears after 5 seconds */}
{showRetryButton && (
  <button onClick={handleRetrySignature}>
    <svg>🔄</svg>
    <span>Retry Signature Request</span>
    {retryCount > 0 && <span>(Attempt {retryCount + 1})</span>}
  </button>
)}

{/* Cancel Button - always visible */}
<button onClick={handleCancel}>
  Cancel
</button>
```

---

## Benefits

### 1. **User Empowerment**
- Users can manually trigger retry without refreshing page
- Clear guidance on what to do if popup blocked
- No need to restart authentication flow

### 2. **Better UX**
- Auto-detects when popup doesn't appear
- Helpful warning message appears automatically
- Progressive disclosure (retry button only when needed)

### 3. **Troubleshooting Built-In**
- Permission request brings MetaMask to foreground
- Retry counter helps track persistence of issues
- Clear error messages guide users to solutions

### 4. **Reduced Support Burden**
- Users can self-solve popup blocker issues
- No need for "refresh page and try again" instructions
- Automatic guidance when problems detected

---

## Console Logs

### Successful Flow:
```javascript
📝 Requesting signature for account: 0x5bedd...
💬 Message to sign: Sign this message...
⏳ Waiting for MetaMask signature popup...
⏰ Showing retry button - signature request may be blocked
🔄 Manual retry signature request triggered
Opening MetaMask... Please check for signature request
✅ Signature obtained successfully
📤 Sending authentication request to backend...
```

### Error Handling:
```javascript
❌ Retry failed: MetaMask is busy. Please check for pending requests
// OR
❌ Retry failed: No wallet address found. Please reconnect your wallet
// OR
❌ Retry failed: Signature request was rejected by user
```

---

## Testing Checklist

### Test 1: Normal Flow (No Issues)
- ✅ Retry button should NOT appear if signature obtained within 5 seconds
- ✅ User signs immediately, authentication completes
- ✅ No retry button shown

### Test 2: Popup Blocked
- ✅ Retry button appears after 5 seconds
- ✅ Warning text shows popup blocker guidance
- ✅ Click retry → MetaMask popup appears
- ✅ Sign → Authentication completes

### Test 3: Multiple Retries
- ✅ Click retry → Counter shows "Attempt 2"
- ✅ Click again → Counter shows "Attempt 3"
- ✅ Each retry triggers new permission request
- ✅ Eventually signature obtained and completes

### Test 4: User Cancellation
- ✅ Click "Cancel" button
- ✅ Modal closes
- ✅ Authentication cancelled
- ✅ Toast: "Authentication cancelled"
- ✅ Can restart authentication flow

### Test 5: Timeout (60 seconds)
- ✅ Wait 60 seconds without signing
- ✅ Timeout error appears
- ✅ Modal closes with error message
- ✅ Can restart authentication

---

## Configuration Options

### Adjust Retry Button Timing
```typescript
// Change from 5 seconds to 3 seconds
const retryTimer = setTimeout(() => {
  setShowRetryButton(true);
}, 3000); // 3 seconds instead of 5
```

### Adjust Timeout Duration
```typescript
// In nonceAuth.ts
const timeoutPromise = new Promise((_, reject) => {
  setTimeout(() => {
    reject(new Error('Signature request timed out...'));
  }, 30000); // 30 seconds instead of 60
});
```

### Customize Retry Behavior
```typescript
// Add maximum retry attempts
if (retryCount >= 3) {
  toast.error('Maximum retry attempts reached. Please refresh page.');
  return;
}
```

---

## Future Enhancements (Optional)

### 1. **Progressive Guidance**
```typescript
// Show different messages based on retry count
if (retryCount === 0) {
  message = "Click MetaMask icon in toolbar";
} else if (retryCount === 1) {
  message = "Check if MetaMask is unlocked";
} else if (retryCount === 2) {
  message = "Try disabling popup blocker";
}
```

### 2. **Visual Pulse Animation**
```css
/* Make retry button pulse to draw attention */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}
.retry-button {
  animation: pulse 2s infinite;
}
```

### 3. **Click MetaMask Extension Button**
```typescript
// Add helper text with visual guide
"👆 Look for the 🦊 icon in your browser toolbar (top-right)"
```

### 4. **Analytics Tracking**
```typescript
// Track how often retry is needed
analytics.track('retry_signature_clicked', {
  retryCount: retryCount,
  timeElapsed: Date.now() - startTime
});
```

---

## Summary

✅ **Implemented**: Manual retry button for signature requests
✅ **Auto-Shows**: After 5 seconds if no signature obtained
✅ **Smart Retry**: Triggers permission request to bring MetaMask forward
✅ **User-Friendly**: Clear guidance and error messages
✅ **No Breaking Changes**: Works seamlessly with existing auth flow

**Result:** Users can now easily recover from popup blocker issues without refreshing the page or restarting the authentication process.

---

## Files Modified

1. **`src/components/wallet/WalletProvider.tsx`**:
   - Added `showRetryButton` and `retryCount` state
   - Added `handleRetrySignature()` function
   - Added 5-second timer to show retry button
   - Enhanced sign-in modal UI with retry button and cancel button

2. **`src/api/nonceAuth.ts`**:
   - Already has timeout protection (60 seconds)
   - Enhanced logging for debugging

---

**Status:** ✅ READY FOR TESTING

Try it now - click "MetaMask" to login and watch for the retry button to appear after 5 seconds! 🚀
