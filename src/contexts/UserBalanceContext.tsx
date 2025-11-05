import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { useAuthState } from '@/hooks/useAuthState';
import userBalanceService from '@/services/UserBalanceService';
import { UserBalance } from '@/types/balance';

interface BalanceContextType {
  balance: UserBalance | null;
  isLoading: boolean;
  refreshBalance: (forceRefresh?: boolean) => Promise<void>;
  updateBalanceOptimistic: (updates: Partial<UserBalance>) => void;
}

const UserBalanceContext = createContext<BalanceContextType>({
  balance: null,
  isLoading: false,
  refreshBalance: async () => {},
  updateBalanceOptimistic: () => {},
});

export const useUserBalance = () => useContext(UserBalanceContext);

interface UserBalanceProviderProps {
  children: ReactNode;
}

export const UserBalanceProvider: React.FC<UserBalanceProviderProps> = ({ children }) => {
  const { isAuthenticated, walletAddress } = useAuthState();
  const [balance, setBalance] = useState<UserBalance | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [subscriptionCleanup, setSubscriptionCleanup] = useState<(() => void) | null>(null);

  /**
   * Load user balance from backend
   * @param forceRefresh - Skip cache and force fresh data from database
   */
  const refreshBalance = useCallback(async (forceRefresh: boolean = false) => {
    if (!isAuthenticated || !walletAddress) {
      setBalance(null);
      return;
    }

    setIsLoading(true);
    try {
      console.log('🔄 [BalanceContext] Loading balance for:', walletAddress);
      const userBalance = await userBalanceService.getUserBalance(walletAddress, forceRefresh);
      setBalance(userBalance);
      console.log('✅ [BalanceContext] Balance loaded:', {
        neft: userBalance.available_neft,
        xp: userBalance.total_xp_earned
      });
    } catch (error) {
      console.error('❌ [BalanceContext] Failed to load balance:', error);
      setBalance(null);
    } finally {
      setIsLoading(false);
    }
  }, [isAuthenticated, walletAddress]);

  /**
   * Optimistic balance update for immediate UI feedback
   * Real balance will be updated when backend sync completes
   */
  const updateBalanceOptimistic = useCallback((updates: Partial<UserBalance>) => {
    setBalance(prev => prev ? { ...prev, ...updates } : null);
    console.log('⚡ [BalanceContext] Optimistic update applied:', updates);
  }, []);

  /**
   * Initial load and wallet change handler
   */
  useEffect(() => {
    if (isAuthenticated && walletAddress) {
      console.log('🔄 [BalanceContext] Auth state changed, loading balance...');
      refreshBalance(false); // Initial load with cache

      // Subscribe to real-time balance updates from UserBalanceService
      const unsubscribe = userBalanceService.subscribeToBalanceUpdates(
        walletAddress,
        (updatedBalance: UserBalance) => {
          console.log('📡 [BalanceContext] Real-time update received:', updatedBalance);
          setBalance(updatedBalance);
        }
      );

      setSubscriptionCleanup(() => unsubscribe);

      return () => {
        if (unsubscribe) {
          unsubscribe();
        }
      };
    } else {
      // Clear balance when logged out
      setBalance(null);
      setIsLoading(false);
      
      if (subscriptionCleanup) {
        subscriptionCleanup();
        setSubscriptionCleanup(null);
      }
    }
  }, [isAuthenticated, walletAddress, refreshBalance]);

  /**
   * Listen for balance update events from various services
   * These events are dispatched when:
   * - Campaign rewards claimed
   * - Daily claim rewards claimed
   * - Achievement rewards claimed
   * - Staking rewards claimed
   * - Referral rewards earned
   */
  useEffect(() => {
    if (!isAuthenticated || !walletAddress) return;

    const handleBalanceUpdate = async (event: Event) => {
      const customEvent = event as CustomEvent;
      console.log('🔔 [BalanceContext] Balance update event:', customEvent.type);
      
      // Force refresh from database to get latest aggregated balance
      await refreshBalance(true);
    };

    // All events that should trigger balance refresh
    const events = [
      'balanceUpdate',
      'rewardClaimed',
      'stakingUpdate',
      'unstakingUpdate',
      'rewards-claimed',
      'tokens-staked',
      'tokens-unstaked',
      'daily-reward-claimed',
      'achievement-unlocked',
      'campaign-reward-claimed',
      'referral-reward-earned',
      'balance-sync-completed'
    ];

    // Add listeners
    events.forEach(event => {
      window.addEventListener(event, handleBalanceUpdate);
    });

    // Cleanup
    return () => {
      events.forEach(event => {
        window.removeEventListener(event, handleBalanceUpdate);
      });
    };
  }, [isAuthenticated, walletAddress, refreshBalance]);

  /**
   * Listen for wallet changes from MetaMask
   */
  useEffect(() => {
    const handleWalletChange = (event: Event) => {
      const customEvent = event as CustomEvent;
      console.log('🔄 [BalanceContext] Wallet changed, clearing balance...');
      setBalance(null);
      setIsLoading(false);
      
      // New balance will be loaded by the auth state effect above
    };

    window.addEventListener('wallet-changed', handleWalletChange);
    return () => window.removeEventListener('wallet-changed', handleWalletChange);
  }, []);

  const contextValue: BalanceContextType = {
    balance,
    isLoading,
    refreshBalance,
    updateBalanceOptimistic,
  };

  return (
    <UserBalanceContext.Provider value={contextValue}>
      {children}
    </UserBalanceContext.Provider>
  );
};

export default UserBalanceContext;
