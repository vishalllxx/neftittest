import { useCallback, useState, useEffect } from 'react';
import { useAuthState } from '@/hooks/useAuthState';
import offChainStakingService from '@/services/EnhancedStakingService';
import userBalanceService from '@/services/UserBalanceService';
import { toast } from 'sonner';
import confetti from 'canvas-confetti';

export const useTokenOperations = () => {
  const { walletAddress } = useAuthState();
  const [stakedAmount, setStakedAmount] = useState<number>(0);
  const [availableAmount, setAvailableAmount] = useState<number>(0);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);

  // Load staking data from backend for real-time verification
  const refreshStakingData = useCallback(async () => {
    if (!walletAddress) return;
    
    setIsRefreshing(true);
    try {
      // Get staking summary from backend (returns StakingSummary directly)
      const summary = await offChainStakingService.getUserStakingSummary(walletAddress);
      setStakedAmount(summary.staked_tokens_amount || 0);
      
      // Get available balance from backend
      const balance = await userBalanceService.getUserBalance(walletAddress);
      setAvailableAmount(balance.available_neft || 0);
      
      console.log('✅ [TokenOperations] Refreshed staking data:', {
        staked: summary.staked_tokens_amount || 0,
        available: balance.available_neft || 0
      });
    } catch (error) {
      console.error('❌ [TokenOperations] Failed to refresh staking data:', error);
    } finally {
      setIsRefreshing(false);
    }
  }, [walletAddress]);

  // Auto-refresh on wallet change
  useEffect(() => {
    if (walletAddress) {
      console.log('🔄 [TokenOperations] Auto-refreshing on wallet change:', walletAddress);
      refreshStakingData();
    }
  }, [walletAddress, refreshStakingData]);

  // Debug log current state
  useEffect(() => {
    console.log('📊 [TokenOperations] Current state:', {
      stakedAmount,
      availableAmount,
      isRefreshing,
      walletAddress
    });
  }, [stakedAmount, availableAmount, isRefreshing, walletAddress]);

  // Stake tokens with backend verification
  const stakeTokens = useCallback(async (amount: number) => {
    if (!walletAddress || amount <= 0) return { success: false, message: 'Invalid parameters' };

    // Validate against real-time available balance
    if (amount > availableAmount) {
      toast.error(`Insufficient balance. Available: ${availableAmount} NEFT`);
      return { success: false, message: 'Insufficient balance' };
    }

    try {
      console.log('🔄 [TokenOperations] Staking tokens:', amount);
      
      const result = await offChainStakingService.stakeTokens(walletAddress, amount);
      
      if (result.success) {
        toast.success(`Successfully staked ${amount} NEFT tokens!`);
        confetti({
          particleCount: 100,
          spread: 70,
          origin: { y: 0.6 }
        });
        
        // Refresh staking data from backend immediately
        await refreshStakingData();
        
        // Emit balance update event for other components
        window.dispatchEvent(new CustomEvent('balance-updated', { 
          detail: { type: 'token-stake', amount } 
        }));
        window.dispatchEvent(new CustomEvent('tokens-staked'));
        
        return { success: true, message: 'Tokens staked successfully' };
      } else {
        throw new Error(result.message || 'Token staking failed');
      }
    } catch (error) {
      console.error('❌ [TokenOperations] Token staking failed:', error);
      toast.error('Failed to stake tokens. Please try again.');
      return { success: false, message: 'Token staking failed' };
    }
  }, [walletAddress, availableAmount, refreshStakingData]);

  // Unstake tokens with backend verification
  const unstakeTokens = useCallback(async (amount: number) => {
    if (!walletAddress || amount <= 0) return { success: false, message: 'Invalid parameters' };

    try {
      console.log('🔄 [TokenOperations] Unstaking tokens:', amount);
      
      // Get staked tokens data to find the staking ID and validate amount
      const stakedTokens = await offChainStakingService.getStakedTokens(walletAddress);
      
      // Check if user has any staked tokens
      if (!stakedTokens || stakedTokens.length === 0) {
        toast.error('No staked tokens found. Please stake tokens first.');
        return { success: false, message: 'No staked tokens found' };
      }
      
      // Calculate total staked from backend (real-time validation)
      const totalStaked = stakedTokens.reduce((sum, st) => sum + (st.amount || 0), 0);
      
      console.log('🔍 [TokenOperations] Unstake validation:', {
        requestedAmount: amount,
        totalStaked,
        stakedTokensCount: stakedTokens.length,
        stakedTokensData: stakedTokens.map(st => ({ id: st.id, amount: st.amount }))
      });
      
      // Validate against actual staked amount from backend
      if (amount > totalStaked) {
        toast.error(`Cannot unstake more than staked amount. Staked: ${totalStaked} NEFT`);
        return { success: false, message: 'Insufficient staked amount' };
      }

      // Sort by amount (largest first) to minimize number of unstake operations
      const sortedStakes = [...stakedTokens].sort((a, b) => (b.amount || 0) - (a.amount || 0));
      
      let remainingToUnstake = amount;
      let totalUnstaked = 0;
      
      // Unstake from records until we've unstaked the full amount
      for (const stake of sortedStakes) {
        if (remainingToUnstake <= 0) break;
        
        const unstakeFromThis = Math.min(remainingToUnstake, stake.amount || 0);
        
        console.log(`🔄 [TokenOperations] Unstaking ${unstakeFromThis} from stake ${stake.id} (has ${stake.amount})`);
        
        const result = await offChainStakingService.unstakeTokens(walletAddress, stake.id, unstakeFromThis);
        
        if (!result.success) {
          throw new Error(result.message || 'Failed to unstake from record');
        }
        
        totalUnstaked += unstakeFromThis;
        remainingToUnstake -= unstakeFromThis;
      }
      
      // Create a success result
      const result = {
        success: true,
        message: `Successfully unstaked ${totalUnstaked} NEFT tokens!`,
        data: { unstaked_amount: totalUnstaked }
      };
      
      if (result.success) {
        toast.success(`Successfully unstaked ${amount} NEFT tokens!`);
        confetti({
          particleCount: 100,
          spread: 70,
          origin: { y: 0.6 }
        });
        
        // Refresh staking data from backend immediately
        await refreshStakingData();
        
        // Emit balance update event for other components
        window.dispatchEvent(new CustomEvent('balance-updated', { 
          detail: { type: 'token-unstake', amount } 
        }));
        window.dispatchEvent(new CustomEvent('tokens-unstaked'));
        
        return { success: true, message: 'Tokens unstaked successfully' };
      } else {
        throw new Error(result.message || 'Token unstaking failed');
      }
    } catch (error) {
      console.error('❌ [TokenOperations] Token unstaking failed:', error);
      toast.error('Failed to unstake tokens. Please try again.');
      // Refresh to show correct state
      await refreshStakingData();
      return { success: false, message: 'Token unstaking failed' };
    }
  }, [walletAddress, stakedAmount, refreshStakingData]);

  return {
    // Token Operations
    stakeTokens,
    unstakeTokens,
    // Real-time data from backend
    stakedAmount,
    availableAmount,
    isRefreshing,
    refreshStakingData
  };
};

export default useTokenOperations;
