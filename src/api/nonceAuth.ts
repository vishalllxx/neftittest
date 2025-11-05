import { supabase } from '@/lib/supabase';
// @ts-ignore - ethers v5 type definitions
import * as ethers from 'ethers';

/**
 * Nonce data structure returned from backend
 */
interface NonceData {
  nonce: string;
  message: string;
  expires_at: string;
}

/**
 * Result of nonce verification
 */
interface NonceVerificationResult {
  valid: boolean;
  message: string | null;
  error_reason: string | null;
}

/**
 * Generate a nonce for wallet authentication
 * @param walletAddress The wallet address requesting a nonce
 * @returns Nonce data including the nonce, message to sign, and expiry time
 */
export async function generateAuthNonce(walletAddress: string): Promise<NonceData> {
  try {
    console.log('🎲 Generating auth nonce for wallet:', walletAddress);
    
    const { data, error } = await supabase.rpc('generate_auth_nonce', {
      p_wallet_address: walletAddress
    });
    
    if (error) {
      console.error('❌ Error generating nonce:', error);
      throw new Error(`Failed to generate nonce: ${error.message}`);
    }
    
    if (!data || data.length === 0) {
      throw new Error('No nonce data returned from server');
    }
    
    const nonceData = data[0];
    console.log('✅ Nonce generated successfully:', {
      nonce: nonceData.nonce.substring(0, 10) + '...',
      expires_at: nonceData.expires_at
    });
    
    return nonceData;
  } catch (error) {
    console.error('❌ Failed to generate nonce:', error);
    throw error;
  }
}

/**
 * Request user to sign a message with their wallet
 * @param message The message to sign
 * @param provider The wallet provider (e.g., window.ethereum)
 * @returns The signature string
 */
export async function requestWalletSignature(
  message: string, 
  provider: any
): Promise<string> {
  try {
    console.log('✍️ Requesting wallet signature...');
    
    // For MetaMask and other EVM wallets
    if (provider.request) {
      // 🔥 CRITICAL FIX: Don't check for accounts first!
      // MetaMask will automatically prompt for unlock when signature is requested
      // Checking eth_accounts first blocks locked wallets from showing unlock prompt
      
      // Try to get accounts, but don't fail if MetaMask is locked
      let account: string | null = null;
      try {
        const accounts = await provider.request({ method: 'eth_accounts' });
        if (accounts && accounts.length > 0) {
          account = accounts[0];
          console.log('✅ Found unlocked account:', account);
        } else {
          console.log('⚠️ No accounts found - wallet may be locked');
        }
      } catch (accountError) {
        console.log('⚠️ Could not get accounts - wallet may be locked, will request unlock via signature');
      }
      
      // If no account found, request accounts (this will trigger MetaMask unlock)
      if (!account) {
        console.log('🔓 Requesting MetaMask to unlock and connect...');
        try {
          const requestedAccounts = await provider.request({ method: 'eth_requestAccounts' });
          if (requestedAccounts && requestedAccounts.length > 0) {
            account = requestedAccounts[0];
            console.log('✅ MetaMask unlocked, account:', account);
          }
        } catch (unlockError: any) {
          // User rejected unlock
          if (unlockError.code === 4001) {
            throw new Error('MetaMask unlock was rejected by user');
          }
          throw unlockError;
        }
      }
      
      if (!account) {
        throw new Error('Could not get account from MetaMask. Please unlock your wallet.');
      }
      
      // Request signature using personal_sign
      // MetaMask will show signature popup (user must be unlocked at this point)
      console.log('📝 Requesting signature for account:', account);
      console.log('💬 Message to sign:', message);
      console.log('⏳ Waiting for MetaMask signature popup...');
      console.log('⚠️ If popup does not appear, check:');
      console.log('  1. Browser popup blocker');
      console.log('  2. MetaMask extension is enabled');
      console.log('  3. No other pending MetaMask requests');
      
      // Add timeout to prevent hanging indefinitely
      const signaturePromise = provider.request({
        method: 'personal_sign',
        params: [message, account]
      });
      
      // Create timeout promise (60 seconds)
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => {
          reject(new Error('Signature request timed out after 60 seconds. Please check if MetaMask popup is blocked or hidden.'));
        }, 60000);
      });
      
      // Race between signature and timeout
      const signature = await Promise.race([signaturePromise, timeoutPromise]);
      
      console.log('✅ Signature obtained successfully');
      return signature;
    }
    
    // For ethers.js provider
    if (provider.getSigner) {
      const signer = await provider.getSigner();
      const signature = await signer.signMessage(message);
      console.log('✅ Signature obtained via ethers signer');
      return signature;
    }
    
    throw new Error('Unsupported wallet provider');
  } catch (error: any) {
    console.error('❌ Signature request failed:', error);
    
    // Handle user rejection
    if (error.code === 4001 || error.message?.includes('User rejected') || error.message?.includes('rejected')) {
      throw new Error('Signature request was rejected by user');
    }
    
    // Handle MetaMask locked error
    if (error.code === -32002) {
      throw new Error('MetaMask is busy. Please check for pending requests in MetaMask.');
    }
    
    throw error;
  }
}

/**
 * Verify a signature locally (client-side verification)
 * @param message The message that was signed
 * @param signature The signature to verify
 * @param expectedAddress The expected wallet address
 * @returns True if signature is valid
 */
export function verifySignatureLocally(
  message: string,
  signature: string,
  expectedAddress: string
): boolean {
  try {
    console.log('🔍 Verifying signature locally...');
    
    // Recover the address from the signature (ethers v5 syntax)
    // @ts-ignore - ethers v5 verifyMessage exists but type definitions may be incomplete
    const recoveredAddress = ethers.utils.verifyMessage(message, signature);
    
    // Compare addresses (case-insensitive)
    const isValid = recoveredAddress.toLowerCase() === expectedAddress.toLowerCase();
    
    if (isValid) {
      console.log('✅ Signature is valid');
    } else {
      console.error('❌ Signature verification failed:', {
        expected: expectedAddress,
        recovered: recoveredAddress
      });
    }
    
    return isValid;
  } catch (error) {
    console.error('❌ Error verifying signature:', error);
    return false;
  }
}

/**
 * Verify and consume a nonce on the backend
 * @param walletAddress The wallet address
 * @param nonce The nonce to verify
 * @returns Verification result
 */
export async function verifyAndConsumeNonce(
  walletAddress: string,
  nonce: string
): Promise<NonceVerificationResult> {
  try {
    console.log('🔐 Verifying and consuming nonce...');
    
    const { data, error } = await supabase.rpc('verify_and_consume_nonce', {
      p_wallet_address: walletAddress,
      p_nonce: nonce
    });
    
    if (error) {
      console.error('❌ Error verifying nonce:', error);
      throw new Error(`Failed to verify nonce: ${error.message}`);
    }
    
    if (!data || data.length === 0) {
      throw new Error('No verification result returned');
    }
    
    const result = data[0];
    
    if (!result.valid) {
      console.error('❌ Nonce verification failed:', result.error_reason);
    } else {
      console.log('✅ Nonce verified and consumed');
    }
    
    return result;
  } catch (error) {
    console.error('❌ Failed to verify nonce:', error);
    throw error;
  }
}

/**
 * Complete wallet authentication flow with nonce and signature
 * @param walletAddress The wallet address to authenticate
 * @param provider The wallet provider (e.g., window.ethereum)
 * @returns Object containing nonce, message, and signature
 */
export async function performNonceBasedAuth(
  walletAddress: string,
  provider: any
): Promise<{
  nonce: string;
  message: string;
  signature: string;
}> {
  try {
    console.log('🔐 Starting nonce-based authentication flow...');
    
    // Step 1: Generate nonce
    const { nonce, message } = await generateAuthNonce(walletAddress);
    
    // Step 2: Request signature from user
    const signature = await requestWalletSignature(message, provider);
    
    // Step 3: Verify signature locally (optional but recommended)
    const isValid = verifySignatureLocally(message, signature, walletAddress);
    if (!isValid) {
      throw new Error('Signature verification failed');
    }
    
    // Step 4: Verify and consume nonce on backend
    const verificationResult = await verifyAndConsumeNonce(walletAddress, nonce);
    if (!verificationResult.valid) {
      throw new Error(verificationResult.error_reason || 'Nonce verification failed');
    }
    
    console.log('✅ Nonce-based authentication completed successfully');
    
    return {
      nonce,
      message,
      signature
    };
  } catch (error) {
    console.error('❌ Nonce-based authentication failed:', error);
    throw error;
  }
}

/**
 * Complete Sui wallet authentication flow with nonce and signature
 * @param suiAddress The Sui wallet address to authenticate
 * @param signMessageFn The Sui wallet's signMessage function
 * @returns Object containing nonce, message, and signature
 */
export async function performSuiNonceAuth(
  suiAddress: string,
  signMessageFn: (params: { message: Uint8Array }) => Promise<any>
): Promise<{
  nonce: string;
  message: string;
  signature: string;
}> {
  try {
    console.log('🔐 Starting Sui nonce-based authentication flow...');
    
    // Step 1: Generate nonce
    const { nonce, message: nonceMessage } = await generateAuthNonce(suiAddress);
    if (!nonce) {
      throw new Error('Failed to generate authentication nonce');
    }
    
    // Step 2: Create message with nonce
    const message = `Sign this message to authenticate with NEFTIT\n\nWallet: ${suiAddress}\nNonce: ${nonce}\nTimestamp: ${Date.now()}`;
    const encodedMessage = new TextEncoder().encode(message);
    
    // Step 3: Request signature from Sui wallet
    console.log('✍️ Requesting Sui wallet signature...');
    const signResult = await signMessageFn({ message: encodedMessage });
    
    if (!signResult || !signResult.signature) {
      throw new Error('Failed to get signature from Sui wallet');
    }
    
    // Step 4: Verify and consume nonce on backend
    console.log('🔐 Verifying nonce on backend...');
    const verificationResult = await verifyAndConsumeNonce(suiAddress, nonce);
    if (!verificationResult.valid) {
      throw new Error(verificationResult.error_reason || 'Nonce verification failed');
    }
    
    console.log('✅ Sui nonce-based authentication completed successfully');
    
    return {
      nonce,
      message,
      signature: signResult.signature
    };
  } catch (error) {
    console.error('❌ Sui nonce-based authentication failed:', error);
    throw error;
  }
}

/**
 * Complete Solana/Phantom wallet authentication flow with nonce and signature
 * @param solanaAddress The Solana wallet address to authenticate
 * @param provider The Solana wallet provider (window.solana)
 * @returns Object containing nonce, message, and signature
 */
export async function performSolanaNonceAuth(
  solanaAddress: string,
  provider: any
): Promise<{
  nonce: string;
  message: string;
  signature: string;
}> {
  try {
    console.log('🔐 Starting Solana/Phantom nonce-based authentication flow...');
    
    // Step 1: Generate nonce
    const { nonce, message: nonceMessage } = await generateAuthNonce(solanaAddress);
    if (!nonce) {
      throw new Error('Failed to generate authentication nonce');
    }
    
    // Step 2: Create message with nonce
    const message = `Sign this message to authenticate with NEFTIT\n\nWallet: ${solanaAddress}\nNonce: ${nonce}\nTimestamp: ${Date.now()}`;
    const encodedMessage = new TextEncoder().encode(message);
    
    // Step 3: Request signature from Phantom wallet
    console.log('✍️ Requesting Phantom/Solana wallet signature...');
    const signResult = await provider.signMessage(encodedMessage, "utf8");
    
    if (!signResult || !signResult.signature) {
      throw new Error('Failed to get signature from Phantom wallet');
    }
    
    // Convert signature to base64
    const signature = btoa(String.fromCharCode(...new Uint8Array(signResult.signature)));
    
    // Step 4: Verify and consume nonce on backend
    console.log('🔐 Verifying nonce on backend...');
    const verificationResult = await verifyAndConsumeNonce(solanaAddress, nonce);
    if (!verificationResult.valid) {
      throw new Error(verificationResult.error_reason || 'Nonce verification failed');
    }
    
    console.log('✅ Solana/Phantom nonce-based authentication completed successfully');
    
    return {
      nonce,
      message,
      signature
    };
  } catch (error) {
    console.error('❌ Solana/Phantom nonce-based authentication failed:', error);
    throw error;
  }
}

/**
 * Get nonce statistics (for debugging/monitoring)
 */
export async function getNonceStats() {
  try {
    const { data, error } = await supabase.rpc('get_nonce_stats');
    
    if (error) {
      console.error('Error getting nonce stats:', error);
      return null;
    }
    
    return data?.[0] || null;
  } catch (error) {
    console.error('Failed to get nonce stats:', error);
    return null;
  }
}
