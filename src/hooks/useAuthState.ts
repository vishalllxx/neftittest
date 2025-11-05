import { useState, useEffect, useCallback } from 'react';
import { getAuthStatus, getWalletAddress, getWalletType, isSocialLogin } from '@/utils/authUtils';

interface AuthState {
  isAuthenticated: boolean;
  walletAddress: string | null;
  walletType: string | null;
  isSocialLogin: boolean;
  isLoading: boolean;
}

/**
 * Custom hook for managing authentication state across the application
 * Centralizes the auth state logic to reduce duplication
 */
export const useAuthState = () => {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    walletAddress: null,
    walletType: null,
    isSocialLogin: false,
    isLoading: true,
  });

  // Update state from localStorage
  const updateAuthState = useCallback(() => {
    const isAuthenticated = getAuthStatus();
    const walletAddress = getWalletAddress();
    const walletType = getWalletType();
    const isSocialAuth = isSocialLogin();

    setAuthState({
      isAuthenticated,
      walletAddress,
      walletType,
      isSocialLogin: isSocialAuth,
      isLoading: false,
    });
  }, []);

  // Initialize on mount and listen for changes
  useEffect(() => {
    // Initial state update
    updateAuthState();

    // Listen for auth status changes
    const handleAuthChange = () => {
      updateAuthState();
    };

    // Listen for custom events from our auth utilities
    window.addEventListener('auth-status-changed', handleAuthChange);
    
    // Listen for storage events (for cross-tab synchronization)
    window.addEventListener('storage', (event) => {
      if (event.key === 'isAuthenticated' || 
          event.key === 'walletAddress' || 
          event.key === 'walletType') {
        updateAuthState();
      }
    });

    // 🔥 NEW: Listen for MetaMask account changes
    const handleMetaMaskAccountChange = (accounts: string[]) => {
      console.log('🔄 MetaMask account changed:', accounts);
      
      if (accounts.length === 0) {
        // User disconnected wallet
        console.log('❌ MetaMask disconnected');
        localStorage.removeItem('walletAddress');
        localStorage.removeItem('isAuthenticated');
        localStorage.removeItem('walletType');
        updateAuthState();
        window.dispatchEvent(new Event('auth-status-changed'));
      } else if (accounts[0] !== getWalletAddress()) {
        // User switched to different account - just log it, don't auto-authenticate
        const newAddress = accounts[0];
        const oldAddress = getWalletAddress();
        console.log('🔄 Wallet address changed from', oldAddress, 'to', newAddress);
        console.log('⚠️ Wallet switch detected - ignoring auto-authentication');
        // Note: WalletProvider now handles correct address extraction from MetaMask provider
      }
    };

    // Add MetaMask event listener if available
    if (typeof window !== 'undefined' && (window as any).ethereum) {
      (window as any).ethereum.on('accountsChanged', handleMetaMaskAccountChange);
    }
    
    return () => {
      window.removeEventListener('auth-status-changed', handleAuthChange);
      window.removeEventListener('storage', handleAuthChange);
      
      // Remove MetaMask listener
      if (typeof window !== 'undefined' && (window as any).ethereum) {
        (window as any).ethereum.removeListener('accountsChanged', handleMetaMaskAccountChange);
      }
    };
  }, [updateAuthState]);

  return authState;
};

export default useAuthState; 