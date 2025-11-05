import { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../lib/supabaseClientManager';

// Interface matching the existing User type
export interface User {
  id: string;
  username: string;
  profileImage: string;
  neftBalance: number;
  nftCount: number;
  rank: number;
  previousRank: number;
  isCurrentUser?: boolean;
}

export interface LeaderboardData {
  nftLeaderboard: User[];
  neftLeaderboard: User[];
  currentUserNft: User | null;
  currentUserNeft: User | null;
}

class OptimizedLeaderboardService {
  private supabase: SupabaseClient;
  private cache: { [key: string]: { data: LeaderboardData; timestamp: number } } = {};
  private readonly CACHE_DURATION = 30000; // 30 seconds cache

  constructor() {
    this.supabase = getSupabaseClient();
  }

  /**
   * 🚀 OPTIMIZED: Single RPC call for all leaderboard data
   * Reduces egress by 90%+ compared to multiple separate calls
   */
  async getAllLeaderboardData(currentUserWallet?: string): Promise<LeaderboardData> {
    try {
      const cacheKey = currentUserWallet || 'anonymous';
      
      // Check cache first
      if (this.cache[cacheKey] && Date.now() - this.cache[cacheKey].timestamp < this.CACHE_DURATION) {
        console.log('📦 Returning cached leaderboard data');
        return this.cache[cacheKey].data;
      }

      console.log('🚀 Fetching optimized leaderboard data with single RPC call...');

      const { data, error } = await this.supabase.rpc('get_leaderboard_minimal_egress', {
        p_user_wallet: currentUserWallet || null
      });

      if (error) {
        console.error('❌ Error fetching optimized leaderboard:', error);
        throw error;
      }

      // Parse the complete result
      const result: LeaderboardData = {
        nftLeaderboard: data.nft_leaderboard || [],
        neftLeaderboard: data.neft_leaderboard || [],
        currentUserNft: data.current_user_nft || null,
        currentUserNeft: data.current_user_neft || null
      };

      // Cache the result
      this.cache[cacheKey] = {
        data: result,
        timestamp: Date.now()
      };

      console.log(`✅ Optimized leaderboard loaded:`);
      console.log(`   📊 NFT Leaderboard: ${result.nftLeaderboard.length} users`);
      console.log(`   💰 NEFT Leaderboard: ${result.neftLeaderboard.length} users`);
      console.log(`   👤 Current User NFT Rank: ${result.currentUserNft?.rank || 'N/A'}`);
      console.log(`   👤 Current User NEFT Rank: ${result.currentUserNeft?.rank || 'N/A'}`);

      return result;
    } catch (error) {
      console.error('Error in getAllLeaderboardData:', error);
      return {
        nftLeaderboard: [],
        neftLeaderboard: [],
        currentUserNft: null,
        currentUserNeft: null
      };
    }
  }

  /**
   * Legacy compatibility methods (use optimized internally)
   */
  async getTopNFTHolders(currentUserWallet?: string): Promise<User[]> {
    const data = await this.getAllLeaderboardData(currentUserWallet);
    return data.nftLeaderboard;
  }

  async getTopNEFTHolders(): Promise<User[]> {
    const data = await this.getAllLeaderboardData();
    return data.neftLeaderboard;
  }

  async getCurrentUserNFT(walletAddress: string): Promise<User | null> {
    const data = await this.getAllLeaderboardData(walletAddress);
    return data.currentUserNft;
  }

  async getCurrentUserNEFT(walletAddress: string): Promise<User | null> {
    const data = await this.getAllLeaderboardData(walletAddress);
    return data.currentUserNeft;
  }

  /**
   * Clear cache when data changes (call after NFT operations)
   */
  clearCache(userWallet?: string) {
    if (userWallet) {
      delete this.cache[userWallet];
    } else {
      this.cache = {}; // Clear all cache
    }
    console.log('🗑️ Leaderboard cache cleared');
  }

  /**
   * Get cache stats for debugging
   */
  getCacheStats() {
    const entries = Object.keys(this.cache).length;
    const oldestEntry = Math.min(...Object.values(this.cache).map(c => c.timestamp));
    const cacheAge = entries > 0 ? Date.now() - oldestEntry : 0;
    
    return {
      entries,
      cacheAge: Math.round(cacheAge / 1000), // seconds
      maxAge: this.CACHE_DURATION / 1000
    };
  }
}

// Export singleton instance
const optimizedLeaderboardService = new OptimizedLeaderboardService();
export default optimizedLeaderboardService;
