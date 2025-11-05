# MetaMask Signature Popup Not Appearing - Troubleshooting Guide

## Issue Description
When clicking "MetaMask" to authenticate, the signature request is sent successfully (visible in console logs) but the MetaMask popup does not appear.

## Console Logs Show:
```
✅ Found unlocked account: 0x5bedd...
📝 Requesting signature for account: 0x5bedd...
⏳ Waiting for MetaMask signature popup...
```

But then... nothing happens. No popup appears.

---

## Common Causes & Solutions

### 1. ✅ Browser Popup Blocker (Most Common)

**Check if popup is blocked:**
- Look for a popup blocker icon in your browser address bar (usually on the right side)
- You may see a notification like "Popup blocked" or a crossed-out popup icon

**Solution:**
1. **Chrome/Edge:** Click the popup blocker icon in address bar → "Always allow popups from neftit.com"
2. **Firefox:** Click the shield icon → Allow popup windows
3. **Brave:** Click the Brave shield → Allow all pop-ups

**Quick Test:**
- Try clicking the MetaMask extension icon directly after clicking login
- The signature request might be waiting there

---

### 2. 🔄 MetaMask Has Pending Request

**Symptoms:**
- Previous signature request is still open
- MetaMask shows "Request already pending"

**Solution:**
1. Click the MetaMask extension icon in browser toolbar
2. Check if there's a pending signature request waiting
3. Either approve or reject the old request
4. Try authentication again

---

### 3. 🦊 MetaMask Extension Not Active

**Check:**
- MetaMask extension is installed and enabled
- Extension icon is visible in browser toolbar
- Extension is not disabled or crashed

**Solution:**
1. Go to browser extensions page:
   - **Chrome/Edge:** `chrome://extensions/`
   - **Firefox:** `about:addons`
   - **Brave:** `brave://extensions/`
2. Find MetaMask and ensure it's enabled
3. If needed, disable and re-enable the extension
4. Reload the NEFTIT page and try again

---

### 4. 🪟 Popup Appearing Behind Other Windows

**Symptoms:**
- Request is sent but popup is hidden
- You can't see MetaMask window

**Solution:**
1. Check your taskbar for a new MetaMask window
2. Press `Alt+Tab` (Windows) or `Cmd+Tab` (Mac) to cycle through windows
3. Look for MetaMask popup window that might be minimized
4. Click the MetaMask extension icon directly

---

### 5. ⚡ Browser Performance/Memory Issue

**Symptoms:**
- Browser is slow or unresponsive
- Multiple tabs open with heavy content

**Solution:**
1. Close unnecessary browser tabs
2. Restart browser completely
3. Clear browser cache:
   - **Chrome/Edge:** Settings → Privacy → Clear browsing data
   - **Firefox:** Settings → Privacy → Clear Data
4. Try authentication again

---

### 6. 🔐 MetaMask Security Settings

**Check:**
- MetaMask may have security settings blocking auto-popups
- Privacy mode enabled

**Solution:**
1. Open MetaMask extension
2. Go to Settings → Advanced
3. Ensure "Show test networks" is enabled (for Polygon Amoy)
4. Check if any security features are blocking popups

---

### 7. 🌐 Network Connection Issue

**Symptoms:**
- Request sent but no response
- Network timeout

**Solution:**
1. Check internet connection
2. Try switching network (WiFi → Mobile hotspot or vice versa)
3. Disable VPN temporarily
4. Check if MetaMask RPC endpoint is responsive

---

## Quick Diagnostic Steps

### Step 1: Check Console for Detailed Logs
Open browser console (F12) and look for:

```javascript
📝 Requesting signature for account: 0x...
💬 Message to sign: Sign this message...
⏳ Waiting for MetaMask signature popup...
⚠️ If popup does not appear, check:
  1. Browser popup blocker
  2. MetaMask extension is enabled
  3. No other pending MetaMask requests
```

### Step 2: Manual MetaMask Check
1. Click the **MetaMask extension icon** directly
2. Look for:
   - ✅ Pending signature request waiting
   - ⚠️ Error message
   - ℹ️ "No pending requests"

### Step 3: Wait for Timeout
The system now has a 60-second timeout. If nothing happens after 60 seconds, you'll see:
```
⏱️ Signature request timed out
Toast: "Signature request timed out. Please check if MetaMask popup is blocked..."
```

---

## Updated Code Features

### 1. ⏱️ Timeout Protection
```typescript
// Request will timeout after 60 seconds with clear error message
const timeoutPromise = new Promise((_, reject) => {
  setTimeout(() => {
    reject(new Error('Signature request timed out after 60 seconds...'));
  }, 60000);
});
```

### 2. 📊 Enhanced Logging
```typescript
console.log('📝 Requesting signature for account:', account);
console.log('💬 Message to sign:', message);
console.log('⏳ Waiting for MetaMask signature popup...');
console.log('⚠️ If popup does not appear, check:');
console.log('  1. Browser popup blocker');
console.log('  2. MetaMask extension is enabled');
console.log('  3. No other pending MetaMask requests');
```

### 3. 🔔 User Guidance Toast
```typescript
toast.info('Check MetaMask extension for signature request...', { 
  duration: 10000,
  description: 'If popup is blocked, click the MetaMask icon in your browser toolbar'
});
```

---

## Testing Procedure

### Test 1: Fresh Browser Session
1. Close browser completely
2. Reopen browser
3. Go to NEFTIT
4. Click "MetaMask" login
5. **Watch for popup immediately**

### Test 2: Click Extension Icon
1. Click "MetaMask" login button
2. **Immediately** click MetaMask extension icon in toolbar
3. Check if signature request is visible there

### Test 3: Different Browser
1. Try Chrome if using Brave
2. Try Firefox if using Chrome
3. Try Edge if using Firefox
4. This helps identify browser-specific issues

---

## Expected Behavior (Working Correctly)

### Console Logs:
```
✅ Found unlocked account: 0x5bedd...
📝 Requesting signature for account: 0x5bedd...
💬 Message to sign: Sign this message to authenticate with NEFTIT...
⏳ Waiting for MetaMask signature popup...
```

### User Experience:
1. Click "MetaMask" button
2. **MetaMask popup appears immediately** (within 1-2 seconds)
3. Popup shows: "Signature Request" with message
4. User clicks "Sign"
5. Success! Redirected to `/discover`

---

## Emergency Workaround

If popup never appears despite all troubleshooting:

### Option 1: Disable Popup Blocker Completely
1. Browser settings → Privacy & Security
2. Find "Pop-ups and redirects"
3. Set to "Sites can send pop-ups and use redirects"
4. Try authentication again

### Option 2: Use Different Wallet Provider
1. If MetaMask continues to have issues
2. Try WalletConnect as alternative
3. Or use social login (Google, Discord, X)

---

## Need More Help?

If none of these solutions work:

1. **Share these details:**
   - Browser name and version
   - Operating system
   - Full console logs (F12 → Console tab)
   - Screenshot of MetaMask extension popup (if visible)
   - Any error messages

2. **Try these diagnostic commands in console:**
```javascript
// Check if MetaMask is detected
console.log('MetaMask:', window.ethereum?.isMetaMask);

// Check current account
window.ethereum?.request({ method: 'eth_accounts' })
  .then(accounts => console.log('Accounts:', accounts));

// Check MetaMask version
console.log('MetaMask version:', window.ethereum?.version);
```

3. **Check browser console for errors:**
   - Look for any red error messages
   - Note any warnings about popup blockers
   - Check for CSP (Content Security Policy) errors

---

## Summary

**Most likely cause:** Browser popup blocker is preventing MetaMask signature popup from appearing.

**Quick fix:** 
1. Click MetaMask extension icon directly after clicking login
2. Allow popups for neftit.com in browser settings
3. Disable popup blocker temporarily

**Verification:** After fixing, you should see MetaMask popup appear within 1-2 seconds of clicking login.
