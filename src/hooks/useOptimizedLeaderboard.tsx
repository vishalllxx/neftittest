import { useState, useEffect, useCallback } from 'react';
import optimizedLeaderboardService, { User, LeaderboardData } from '@/services/OptimizedLeaderboardService';

interface UseOptimizedLeaderboardReturn {
  neftLeaderboard: User[];
  nftLeaderboard: User[];
  currentUserNft: User | null;
  currentUserNeft: User | null;
  isLoading: boolean;
  error: string | null;
  refreshLeaderboards: () => Promise<void>;
  cacheStats: {
    entries: number;
    cacheAge: number;
    maxAge: number;
  };
}

export const useOptimizedLeaderboard = (currentUserWallet?: string): UseOptimizedLeaderboardReturn => {
  const [leaderboardData, setLeaderboardData] = useState<LeaderboardData>({
    nftLeaderboard: [],
    neftLeaderboard: [],
    currentUserNft: null,
    currentUserNeft: null
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadLeaderboards = useCallback(async () => {
    try {
      setError(null);
      console.log('🚀 Loading optimized leaderboards...');

      // Single RPC call for all data - massive egress reduction!
      const data = await optimizedLeaderboardService.getAllLeaderboardData(currentUserWallet);
      setLeaderboardData(data);

      console.log('✅ Optimized leaderboards loaded successfully');
    } catch (err) {
      console.error('❌ Error loading optimized leaderboards:', err);
      setError('Failed to load leaderboard data');
    } finally {
      setIsLoading(false);
    }
  }, [currentUserWallet]);

  const refreshLeaderboards = useCallback(async () => {
    setIsLoading(true);
    optimizedLeaderboardService.clearCache(currentUserWallet); // Clear cache for fresh data
    await loadLeaderboards();
  }, [loadLeaderboards, currentUserWallet]);

  // Load data on mount and when user changes
  useEffect(() => {
    loadLeaderboards();
  }, [loadLeaderboards]);

  return {
    neftLeaderboard: leaderboardData.neftLeaderboard,
    nftLeaderboard: leaderboardData.nftLeaderboard,
    currentUserNft: leaderboardData.currentUserNft,
    currentUserNeft: leaderboardData.currentUserNeft,
    isLoading,
    error,
    refreshLeaderboards,
    cacheStats: optimizedLeaderboardService.getCacheStats()
  };
};
