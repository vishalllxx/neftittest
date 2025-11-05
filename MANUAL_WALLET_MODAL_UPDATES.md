# Manual Updates for WalletConnectionModal.tsx

## ⚠️ Important: Copy-Paste Instructions

You have the file open in your editor. Please manually update the following sections:

---

## Update 1: Phantom Handler (Lines ~504-528)

### Find this code block:
```typescript
      if (!solAddress) {
        toast.error("Failed to get Solana address from Phantom.");
        setIsLoading(prev => ({ ...prev, Phantom: false }));
        return;
      }
      // 3. Sign a message for authentication
      const message = `Sign in to NEFTIT with Solana wallet: ${solAddress}`;
      const encodedMessage = new TextEncoder().encode(message);
      let signature;
      try {
        const signed = await (provider as any).signMessage(encodedMessage, "utf8");
        signature = signed.signature ? btoa(String.fromCharCode(...new Uint8Array(signed.signature))) : undefined;
      } catch (e) {
        toast.error("Signature request was rejected.");
        setIsLoading(prev => ({ ...prev, Phantom: false }));
        return;
      }
      // 4. Authenticate with backend using unified system
      const { processWalletLogin } = await import("@/api/walletAuth");
      const walletAddress = `${solAddress}`;
      const authResult = await processWalletLogin(walletAddress, 'phantom', {
        signature,
        timestamp: new Date().toISOString(),
        provider_type: 'solana'
      });
```

### Replace with this:
```typescript
      if (!solAddress) {
        toast.error("Failed to get Solana address from Phantom.");
        setIsLoading(prev => ({ ...prev, Phantom: false }));
        return;
      }
      
      // 3. Generate nonce and request signature for authentication
      toast.info('Please sign the message in Phantom to authenticate...', { duration: 3000 });
      
      let nonce: string;
      let authMessage: string;
      let signature: string;
      
      try {
        // Generate nonce from backend
        const nonceData = await generateAuthNonce(solAddress);
        nonce = nonceData.nonce;
        authMessage = nonceData.message;
        
        // Request signature from Phantom
        const encodedMessage = new TextEncoder().encode(authMessage);
        const signed = await (provider as any).signMessage(encodedMessage, "utf8");
        signature = signed.signature ? btoa(String.fromCharCode(...new Uint8Array(signed.signature))) : '';
        
        if (!signature) {
          throw new Error('Failed to obtain signature');
        }
        
        console.log('✅ Phantom signature obtained');
        
        // Verify nonce on backend
        const nonceVerification = await verifyAndConsumeNonce(solAddress, nonce);
        if (!nonceVerification.valid) {
          throw new Error(nonceVerification.error_reason || 'Nonce verification failed');
        }
        
      } catch (e: any) {
        if (e.message?.includes('rejected') || e.code === 4001) {
          toast.error("Signature request was rejected.");
        } else {
          toast.error("Failed to authenticate: " + (e.message || 'Unknown error'));
        }
        setIsLoading(prev => ({ ...prev, Phantom: false }));
        setConnectingWallet(null);
        setShowConnectingModal(false);
        return;
      }
      
      // 4. Authenticate with backend using unified system
      const { processWalletLogin } = await import("@/api/walletAuth");
      const walletAddress = `${solAddress}`;
      const authResult = await processWalletLogin(walletAddress, 'phantom', {
        signature,
        message: authMessage,
        nonce,
        timestamp: new Date().toISOString(),
        provider_type: 'solana'
      });
```

---

## Update 2: Sui Handler (Lines ~588-598)

### Find this code block:
```typescript
      // Sign a message for verification
      const message = `Sign in to NEFTIT with Sui wallet: ${suiAddress}`;
      const encodedMessage = new TextEncoder().encode(message);
      const result = await signMessage({ message: encodedMessage });

      // Use unified wallet authentication system
      const { processWalletLogin } = await import('@/api/walletAuth');
      const authResult = await processWalletLogin(suiAddress, 'sui', {
        name: `Sui_${suiAddress.slice(0, 6)}`,
        signature: result
      });
```

### Replace with this:
```typescript
      // Generate nonce and sign message for verification
      toast.info('Please sign the message in your Sui wallet to authenticate...', { duration: 3000 });
      
      let nonce: string;
      let authMessage: string;
      let signature: any;
      
      try {
        // Generate nonce from backend
        const nonceData = await generateAuthNonce(suiAddress);
        nonce = nonceData.nonce;
        authMessage = nonceData.message;
        
        // Request signature from Sui wallet
        const encodedMessage = new TextEncoder().encode(authMessage);
        signature = await signMessage({ message: encodedMessage });
        
        // Verify nonce on backend
        const nonceVerification = await verifyAndConsumeNonce(suiAddress, nonce);
        if (!nonceVerification.valid) {
          throw new Error(nonceVerification.error_reason || 'Nonce verification failed');
        }
        
        console.log('✅ Sui signature obtained and verified');
      } catch (sigError: any) {
        if (sigError.message?.includes('rejected') || sigError.code === 4001) {
          toast.error('Signature request was rejected.');
        } else {
          toast.error('Failed to authenticate: ' + (sigError.message || 'Unknown error'));
        }
        setIsLoading((prev) => ({ ...prev, Sui: false }));
        setConnectingWallet(null);
        setShowConnectingModal(false);
        return;
      }

      // Use unified wallet authentication system
      const { processWalletLogin } = await import('@/api/walletAuth');
      const authResult = await processWalletLogin(suiAddress, 'sui', {
        name: `Sui_${suiAddress.slice(0, 6)}`,
        signature,
        message: authMessage,
        nonce
      });
```

---

## ✅ Verification Steps

After making these changes:

1. **Check for errors**: Ensure no TypeScript errors appear
2. **Save the file**: Ctrl+S / Cmd+S
3. **Check imports**: Verify line 15 has: `import { generateAuthNonce, verifyAndConsumeNonce } from '@/api/nonceAuth';`

---

## 🧪 Testing

After updating, test each wallet:

### Test Phantom:
1. Click "Connect Phantom"
2. Approve connection
3. **Should see toast**: "Please sign the message in Phantom to authenticate..."
4. Sign the message
5. Should redirect to /discover

### Test Sui:
1. Click "Connect Sui"
2. Approve connection
3. **Should see toast**: "Please sign the message in your Sui wallet to authenticate..."
4. Sign the message
5. Should redirect to /discover

---

## 📝 Notes

- The import statement was already added at line 15
- MetaMask already works with nonce auth via WalletProvider
- These updates add nonce auth to Phantom and Sui wallets
- All signature verification happens server-side for security

---

## ❓ Need Help?

If you encounter issues:
1. Check browser console for error messages
2. Verify the SQL functions are deployed in Supabase
3. Ensure all imports are correct
4. Check that `ethers` package is installed

The core system is complete - these are just the final UI touchpoints!
