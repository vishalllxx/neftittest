import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useAuthState } from '@/hooks/useAuthState';
// Removed ComprehensiveNFTDataService - using direct services for better performance
import { nftLifecycleService, OffchainNFT, OnchainNFT } from '@/services/NFTLifecycleService';
import offChainStakingService from '@/services/EnhancedStakingService';
import improvedOnchainStakingService from '@/services/ImprovedOnchainStakingService';
import optimizedCIDPoolBurnService from '@/services/OptimizedCIDPoolBurnService';
import { nftCountTrackingService } from '@/services/NFTCountTrackingService';
import { chainManager } from '@/services/ChainManagerService';
import { AVAILABLE_CHAINS, SUPPORTED_CHAINS, getChainByNetwork } from '@/config/chains';
import { multichainNFTLoader } from '@/services/MultichainNFTLoader';
import { toast } from 'sonner';

// Enhanced NFT interface for context - optimized standalone interface
export interface ContextNFT {
  id: string;
  name: string;
  description?: string;
  image: string;
  rarity: string;
  attributes?: any[];
  status: 'offchain' | 'onchain';
  isStaked: boolean;
  stakingSource: 'none' | 'offchain' | 'onchain';
  dailyReward: number;
  wallet_address: string;
  // Additional metadata
  ipfs_hash?: string;
  metadata_uri?: string;
  tokenId?: string;
  contractAddress?: string;
  claimed_at?: string;
  staked_at?: string;
  // Onchain-specific properties
  transactionHash?: string;
  metadataURI?: string;
  claimed_blockchain?: string;
  // Multichain properties
  blockchain?: string; // Network identifier (e.g., 'polygon-amoy', 'sepolia', 'bsc-testnet')
  chainId?: number; // Chain ID for the blockchain
  chainName?: string; // Human-readable chain name
  chainIconUrl?: string; // Chain logo URL
  // Chain-specific distribution properties
  assigned_chain?: string; // Blockchain this NFT is assigned to (from CID pool distribution)
  chain_contract_address?: string; // Contract address on assigned chain
  can_claim_to_any_chain?: boolean; // If true, can claim to any chain; if false, only to assigned_chain
  ipfs_cid?: string; // IPFS CID for chain validation
  // Real-time sync properties
  stakeTimestamp?: number;
  lastUpdated?: number;
  optimisticUpdate?: boolean;
  // Claiming status
  claimingStatus?: 'claiming' | 'completed' | 'failed';
  // PRESERVE ORIGINAL BLOCKCHAIN METADATA - Don't let database overwrite this
  originalBlockchainMetadata?: {
    name: string;
    image: string;
    rarity: string;
    tokenId?: string;
    contractAddress?: string;
    metadataURI?: string;
  };
}

interface NFTContextState {
  // Auth State
  isAuthenticated: boolean;
  walletAddress: string | null;
  
  // NFT Data
  allNFTs: ContextNFT[];
  offchainNFTs: OffchainNFT[];
  onchainNFTs: OnchainNFT[];
  
  // Filtered Views
  availableNFTs: ContextNFT[]; // For burning/claiming
  stakableNFTs: ContextNFT[];  // For staking
  stakedNFTs: ContextNFT[];    // Currently staked
  
  // States
  isLoading: boolean;
  isInitialized: boolean;
  lastUpdated: Date | null;
  
  // Streaming Loading States
  isLoadingMore: boolean;
  hasMoreToLoad: boolean;
  loadingProgress: {
    offchain: boolean;
    comprehensive: boolean;
    onchain: boolean;
    staking: boolean;
    total: number;
    completed: number;
  };
  
  // Actions
  loadNFTData: () => Promise<void>;
  refreshNFTs: () => Promise<void>;
  forceReloadNFTs: () => Promise<void>;
  ensureNFTsLoaded: () => Promise<void>;
  syncStakingStatus: () => Promise<void>;
  
  // Optimistic Updates
  updateNFTOptimistically: (nftId: string, updates: Partial<ContextNFT>) => void;
  batchUpdateNFTs: (updates: Array<{id: string, changes: Partial<ContextNFT>}>) => void;
  optimisticStake: (nftIds: string[], stakingSource?: 'offchain' | 'onchain') => void;
  optimisticUnstake: (nftIds: string[]) => void;
  optimisticBurn: (nftIds: string[], newNFT?: ContextNFT) => void;
  optimisticClaimStart: (nftId: string) => void;
  optimisticClaim: (nftId: string) => void;
  
  // Claiming Functions
  handleSuccessfulClaim: (offchainNftId: string, onchainNft: ContextNFT) => void;
  revertOptimisticUpdate: () => void;
  clearOptimisticUpdates: () => void;
  confirmDatabaseSync: (nftIds: string[]) => Promise<void>;
  
  // NFT Count Sync
  syncNFTCountsToBackend: () => Promise<void>;
}

const NFTContext = createContext<NFTContextState | undefined>(undefined);

export const useNFTContext = () => {
  const context = useContext(NFTContext);
  if (!context) {
    throw new Error('useNFTContext must be used within an NFTProvider');
  }
  return context;
};

interface NFTProviderProps {
  children: React.ReactNode;
}

export const NFTProvider: React.FC<NFTProviderProps> = ({ children }) => {
  const { walletAddress, isAuthenticated } = useAuthState();
  
  // Core State - Initialize with proper loading state
  const [allNFTs, setAllNFTs] = useState<ContextNFT[]>([]);
  const [offchainNFTs, setOffchainNFTs] = useState<OffchainNFT[]>([]);
  const [onchainNFTs, setOnchainNFTs] = useState<OnchainNFT[]>([]);
  const [isLoading, setIsLoading] = useState(true); // Start with loading true to prevent flash of old content
  const [isInitialized, setIsInitialized] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [backupState, setBackupState] = useState<ContextNFT[]>([]);
  
  // STREAMING LOADING: Show NFTs as they load individually
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [hasMoreToLoad, setHasMoreToLoad] = useState(false);
  const [loadingProgress, setLoadingProgress] = useState({
    offchain: false,
    comprehensive: false,
    onchain: false,
    staking: false,
    total: 4,
    completed: 0
  });
  
  // PERFORMANCE: Cache to prevent unnecessary reloads
  const [lastWalletAddress, setLastWalletAddress] = useState<string | null>(null);
  const [cacheExpiry, setCacheExpiry] = useState<Date | null>(null);
  const [hasOptimisticUpdates, setHasOptimisticUpdates] = useState(false);

  // Computed values
  const availableNFTs = allNFTs.filter(nft => !nft.isStaked);
  const stakableNFTs = allNFTs.filter(nft => !nft.isStaked);
  const stakedNFTs = allNFTs.filter(nft => nft.isStaked);

  // Sync NFT counts to backend for leaderboard
  const syncNFTCountsToBackend = useCallback(async () => {
    if (!walletAddress || !isAuthenticated) {
      return;
    }

    try {
      const result = await nftCountTrackingService.updateUserNFTCounts(walletAddress);
      
      if (!result) {
        console.warn('NFT count sync returned null');
      }
    } catch (error) {
      console.error('Failed to sync NFT counts:', error);
    }
  }, [walletAddress, isAuthenticated]);

  // Main loading function with progressive streaming
  const loadNFTData = useCallback(async (): Promise<void> => {
    if (!walletAddress) {
      setAllNFTs([]);
      setOffchainNFTs([]);
      setOnchainNFTs([]);
      setIsLoading(false);
      setIsInitialized(true);
      return;
    }

    setIsLoading(true);
    setLoadingProgress({ offchain: false, comprehensive: false, onchain: false, staking: false, total: 4, completed: 0 });

    try {
      // 1. Load offchain NFTs first (fastest)
      const offchainData = await nftLifecycleService.loadOffchainNFTs(walletAddress);
      
      if (offchainData && offchainData.length > 0) {
        // Include all offchain NFTs (including staked ones)
        const activeOffchainNFTs = offchainData.filter(nft => 
          nft.status === 'offchain' || nft.status === 'claiming'
        );
        
        
        if (activeOffchainNFTs.length > 0) {
          const contextNFTs: ContextNFT[] = activeOffchainNFTs.map(nft => ({
            ...nft,
            status: 'offchain' as const,
            isStaked: nft.isStaked || false,
            stakingSource: nft.isStaked ? 'offchain' as const : 'none' as const,
            dailyReward: offChainStakingService.getDailyRewardForRarity(nft.rarity)
          }));
          
          setAllNFTs(contextNFTs);
          setOffchainNFTs(activeOffchainNFTs);
        }
      }
      setLoadingProgress(prev => ({ ...prev, offchain: true, completed: prev.completed + 1 }));

      // 2. Load onchain NFTs from ALL chains (multichain support)
      console.log('⛓️ [NFTContext] Loading onchain NFTs from ALL chains...');
      setLoadingProgress(prev => ({ ...prev, onchain: false, completed: 1 })); // Show onchain loading started
      
      try {
        // Use MultichainNFTLoader to load from all chains WITHOUT switching user's current chain
        console.log(`🌐 [NFTContext] Fetching NFTs from ${AVAILABLE_CHAINS.length} chains in parallel...`);
        
        const onchainData = await multichainNFTLoader.loadAllChainNFTs(walletAddress);
        
        console.log(`🌐 [NFTContext] Total multichain NFTs loaded: ${onchainData.length}`);
        console.log('🔍 [NFTContext] Multichain NFTs by network:', onchainData);
        
        if (onchainData && onchainData.length > 0) {
          console.log(`✅ [NFTContext] Loaded ${onchainData.length} onchain NFTs from all chains`);
          setOnchainNFTs(onchainData);
          
          // Add new onchain NFTs to context - PRESERVE ORIGINAL BLOCKCHAIN METADATA
          setAllNFTs(currentNFTs => {
            // Convert onchain NFTs to context format with proper reward calculation
            // Filter out reward tracking entries from UI display
            const newOnchainNFTs = onchainData
              .filter(nft => 
                !currentNFTs.some(existing => existing.id === nft.id) &&
                !nft.id.includes('onchain_reward_') &&
                nft.status !== 'reward_tracking'
              )
              .map(nft => ({
                ...nft,
                status: 'onchain' as const,
                stakingSource: nft.isStaked ? 'onchain' as const : 'none' as const,
                dailyReward: offChainStakingService.getDailyRewardForRarity(nft.rarity),
                isStaked: nft.isStaked || false,
                stakeTimestamp: nft.stakeTimestamp,
                // Chain metadata already added above
                blockchain: nft.blockchain,
                chainId: nft.chainId,
                chainName: nft.chainName,
                chainIconUrl: nft.chainIconUrl,
                // PRESERVE ORIGINAL BLOCKCHAIN METADATA - Don't let database overwrite this
                originalBlockchainMetadata: {
                  name: nft.name,
                  image: nft.image,
                  rarity: nft.rarity,
                  tokenId: nft.tokenId,
                  contractAddress: nft.contractAddress,
                  metadataURI: nft.metadataURI
                }
              }));
            
            if (newOnchainNFTs.length > 0) {
              console.log(`📊 [NFTContext] Added ${newOnchainNFTs.length} new onchain NFTs to context with preserved blockchain metadata:`, newOnchainNFTs.map(nft => `${nft.id} (${nft.name})`));
              return [...currentNFTs, ...newOnchainNFTs];
            }
            return currentNFTs;
          });
        } else {
          console.log('📊 [NFTContext] No onchain NFTs found - this could mean:');
          console.log('  - Wallet has no NFTs on blockchain');
          console.log('  - Blockchain connection failed');
          console.log('  - Contract address is incorrect');
          console.log('  - RPC endpoints are not responding');
        }
      } catch (error) {
        console.error('❌ [NFTContext] Failed to load onchain NFTs:', error);
        console.error('❌ [NFTContext] Error details:', {
          message: error.message,
          stack: error.stack,
          walletAddress
        });
      }
      
      setLoadingProgress(prev => ({ ...prev, onchain: true, completed: prev.completed + 1 }));

      // Set cache and complete loading
      const cacheExpiry = new Date(Date.now() + 2 * 60 * 1000); // 2 minutes (reduced from 10 for better auto-refresh)
      setCacheExpiry(cacheExpiry);
      setLastWalletAddress(walletAddress);
      setHasOptimisticUpdates(false);
      
    } catch (error) {
      console.error('❌ [NFTContext] Failed to load NFT data:', error);
      toast.error('Failed to load NFT data');
    } finally {
      setIsLoading(false);
      setIsInitialized(true);
      setLastUpdated(new Date());
      setLoadingProgress(prev => ({ ...prev, completed: prev.total }));
      
      // Sync NFT counts to backend after loading
      if (walletAddress && isAuthenticated) {
        setTimeout(() => {
          syncNFTCountsToBackend();
        }, 2000); // Delay to ensure all data is loaded
      }
    }
  }, [walletAddress, isAuthenticated, syncNFTCountsToBackend]);

  // Optimistic Updates
  const optimisticStake = useCallback((nftIds: string[], stakingSource: 'offchain' | 'onchain' = 'offchain') => {
    console.log('🔄 [NFTContext] Optimistic stake:', nftIds, 'source:', stakingSource);
    setBackupState([...allNFTs]);
    setHasOptimisticUpdates(true);
    
    // Import the reward calculation function
    const getDailyRewardForRarity = (rarity: string): number => {
      const rewards: Record<string, number> = {
        'common': 0.1,
        'rare': 0.4,
        'legendary': 1.0,
        'platinum': 2.5,
        'silver': 8.0,
        'gold': 30.0
      };
      return rewards[rarity.toLowerCase()] || 0.1;
    };
    
    setAllNFTs(prev => prev.map(nft => 
      nftIds.includes(nft.id) 
        ? { 
            ...nft, 
            isStaked: true, 
            stakingSource: stakingSource, 
            stakeTimestamp: Date.now(),
            dailyReward: getDailyRewardForRarity(nft.rarity)
          }
        : nft
    ));
  }, [allNFTs]);

  const optimisticUnstake = useCallback((nftIds: string[]) => {
    console.log('🔄 [NFTContext] Optimistic unstake:', nftIds);
    setBackupState([...allNFTs]);
    setHasOptimisticUpdates(true);
    
    setAllNFTs(prev => prev.map(nft => 
      nftIds.includes(nft.id) 
        ? { ...nft, isStaked: false, stakingSource: 'none' as const, stakeTimestamp: undefined }
        : nft
    ));
  }, [allNFTs]);

  const optimisticClaimStart = useCallback((nftId: string) => {
    console.log('🔄 [NFTContext] Starting claim (showing claiming status):', nftId);
    setBackupState([...allNFTs]);
    
    setAllNFTs(prev => prev.map(nft => 
      nft.id === nftId 
        ? { 
            ...nft, 
            status: 'offchain' as const, // Keep as offchain during claiming
            claimingStatus: 'claiming', // Add separate claiming status
            optimisticUpdate: true 
          }
        : nft
    ));
  }, [allNFTs]);

  const optimisticClaim = useCallback((nftId: string) => {
    console.log('🔄 [NFTContext] Optimistic claim completed - removing offchain NFT:', nftId);
    setAllNFTs(prev => prev.filter(nft => nft.id !== nftId));
    setOffchainNFTs(prev => prev.filter(nft => nft.id !== nftId));
    // Don't trigger any reloads - the NFT is now claimed and should disappear from offchain list
    console.log('✅ [NFTContext] NFT successfully removed from offchain collection');
  }, []);

  const optimisticBurn = useCallback((nftIds: string[], newNFT?: ContextNFT) => {
    console.log('🔄 [NFTContext] Optimistic burn:', nftIds, newNFT);
    setBackupState([...allNFTs]);
    
    setAllNFTs(prev => {
      let updated = prev.filter(nft => !nftIds.includes(nft.id));
      if (newNFT) {
        updated.push(newNFT);
      }
      return updated;
    });
  }, [allNFTs]);

  const updateNFTOptimistically = useCallback((nftId: string, updates: Partial<ContextNFT>) => {
    console.log('🔄 [NFTContext] Optimistic update for NFT:', nftId, updates);
    setBackupState([...allNFTs]);
    setHasOptimisticUpdates(true);
    
    setAllNFTs(prev => prev.map(nft => 
      nft.id === nftId 
        ? { ...nft, ...updates, lastUpdated: Date.now(), optimisticUpdate: true }
        : nft
    ));
  }, [allNFTs]);

  const batchUpdateNFTs = useCallback((updates: Array<{id: string, changes: Partial<ContextNFT>}>) => {
    console.log('🔄 [NFTContext] Batch optimistic updates:', updates);
    setBackupState([...allNFTs]);
    setHasOptimisticUpdates(true);
    
    setAllNFTs(prev => prev.map(nft => {
      const update = updates.find(u => u.id === nft.id);
      return update 
        ? { ...nft, ...update.changes, lastUpdated: Date.now(), optimisticUpdate: true }
        : nft;
    }));
  }, [allNFTs]);

  const revertOptimisticUpdate = useCallback(() => {
    console.log('🔄 [NFTContext] Reverting optimistic update');
    if (backupState.length > 0) {
      setAllNFTs(backupState);
      setBackupState([]);
      setHasOptimisticUpdates(false);
    }
  }, [backupState]);

  const clearOptimisticUpdates = useCallback(() => {
    console.log('✅ [NFTContext] Clearing optimistic updates flag');
    setBackupState([]);
    setHasOptimisticUpdates(false);
  }, []);

  // Confirm database sync without overriding optimistic updates
  const confirmDatabaseSync = useCallback(async (nftIds: string[]) => {
    if (!walletAddress || !isAuthenticated) return;
    
    try {
      console.log('🔍 [NFTContext] Confirming database sync for NFTs:', nftIds);
      
      // Fetch fresh staked NFTs from database
      const stakedNFTs = await offChainStakingService.getStakedNFTs(walletAddress);
      const stakedIds = new Set(stakedNFTs.map(nft => nft.id || nft.nft_id));
      
      // Check if all NFTs are confirmed in database
      const allConfirmed = nftIds.every(id => stakedIds.has(id));
      
      if (allConfirmed) {
        console.log('✅ [NFTContext] All NFTs confirmed in database - clearing optimistic updates');
        clearOptimisticUpdates();
        
        // Update NFTs with database data to ensure consistency
        setAllNFTs(prev => prev.map(nft => {
          if (nftIds.includes(nft.id)) {
            const dbNFT = stakedNFTs.find(staked => (staked.id || staked.nft_id) === nft.id);
            if (dbNFT) {
              return {
                ...nft,
                isStaked: true,
                stakingSource: 'offchain' as const,
                stakeTimestamp: new Date(dbNFT.staked_at).getTime(),
                dailyReward: dbNFT.daily_reward || nft.dailyReward
              };
            }
          }
          return nft;
        }));
      } else {
        console.warn('⚠️ [NFTContext] Not all NFTs confirmed in database yet - keeping optimistic updates');
      }
    } catch (error) {
      console.error('❌ [NFTContext] Failed to confirm database sync:', error);
    }
  }, [walletAddress, isAuthenticated, clearOptimisticUpdates]);

  const handleSuccessfulClaim = useCallback((offchainNftId: string, onchainNft: ContextNFT) => {
    console.log('✅ [NFTContext] Successful claim - updating NFT states');
    console.log('📝 [NFTContext] Removing offchain NFT:', offchainNftId);
    console.log('➕ [NFTContext] Adding onchain NFT:', onchainNft);
    
    setAllNFTs(prev => {
      // Remove the offchain NFT and add the onchain NFT
      const filtered = prev.filter(nft => nft.id !== offchainNftId);
      return [...filtered, onchainNft];
    });
    
    setOffchainNFTs(prev => prev.filter(nft => nft.id !== offchainNftId));
    
    // Add to onchain NFTs if it has blockchain data
    if (onchainNft.tokenId && onchainNft.transactionHash) {
      // Convert ContextNFT to OnchainNFT format - PRESERVE CHAIN INFO
      const onchainNFTData: OnchainNFT = {
        id: onchainNft.id,
        name: onchainNft.name,
        description: onchainNft.description || '',
        image: onchainNft.image,
        rarity: onchainNft.rarity,
        attributes: onchainNft.attributes || [],
        tokenId: onchainNft.tokenId,
        transactionHash: onchainNft.transactionHash,
        contractAddress: onchainNft.contractAddress || '',
        metadataURI: onchainNft.metadataURI || onchainNft.metadata_uri || '',
        wallet_address: onchainNft.wallet_address,
        claimed_at: onchainNft.claimed_at || new Date().toISOString(),
        claimed_blockchain: onchainNft.claimed_blockchain || 'polygon',
        status: 'onchain' as const,
        // PRESERVE CHAIN INFORMATION FOR LOGO DISPLAY
        blockchain: onchainNft.blockchain,
        chainId: onchainNft.chainId,
        chainName: onchainNft.chainName,
        chainIconUrl: onchainNft.chainIconUrl
      };
      
      setOnchainNFTs(prev => [...prev, onchainNFTData]);
      console.log('✅ [NFTContext] Onchain NFT added to onchain collection');
    }
    
    console.log('✅ [NFTContext] Claim completed - NFT moved from offchain to onchain');
  }, []);

  // Auto-loading when authentication changes
  useEffect(() => {
    const authCheckTimeout = setTimeout(() => {
      console.log('🔄 [NFTContext] Auth check:', { 
        walletAddress, 
        isAuthenticated, 
        lastWalletAddress,
        walletChanged: lastWalletAddress !== walletAddress && lastWalletAddress !== null
      });
      
      if (isAuthenticated && walletAddress) {
        const walletChanged = lastWalletAddress !== walletAddress && lastWalletAddress !== null;
        const hasNoData = allNFTs.length === 0 && !isInitialized;
        const cacheExpired = cacheExpiry && Date.now() > cacheExpiry.getTime();
        // REMOVED: onchainNotLoaded check - it was causing infinite reload loop!
        // Onchain loading happens automatically in loadNFTData(), no need to check separately
        const needsReload = walletChanged || hasNoData || cacheExpired;
        
        if (needsReload) {
          console.log('🔄 [NFTContext] Loading NFT data...', { 
            walletChanged, 
            hasNoData, 
            cacheExpired
          });
          
          if (walletChanged) {
            console.log('🔄 [NFTContext] Wallet changed, clearing old data');
            setAllNFTs([]);
            setOffchainNFTs([]);
            setOnchainNFTs([]);
            setCacheExpiry(null);
          }
          
          setIsLoading(true);
          setLastWalletAddress(walletAddress);
          loadNFTData().catch(error => {
            console.error('❌ [NFTContext] Failed to load NFT data:', error);
            setIsLoading(false);
            setIsInitialized(true);
          });
        } else {
          console.log('⚡ [NFTContext] Skipping reload - data already loaded', {
            allNFTs: allNFTs.length,
            offchainNFTs: offchainNFTs.length,
            onchainNFTs: onchainNFTs.length,
            onchainLoaded: loadingProgress.onchain
          });
          if (allNFTs.length > 0) {
            setIsLoading(false);
            setIsInitialized(true);
          }
        }
      } else if (!isAuthenticated && lastWalletAddress) {
        console.log('🔄 [NFTContext] User logged out, clearing NFT data...');
        setAllNFTs([]);
        setOffchainNFTs([]);
        setOnchainNFTs([]);
        setLastWalletAddress(null);
        setCacheExpiry(null);
        setIsLoading(false);
        setIsInitialized(true);
      }
    }, 100); // Reduced from 500ms to 100ms for faster initial load
    
    return () => clearTimeout(authCheckTimeout);
  }, [walletAddress, isAuthenticated, lastWalletAddress, allNFTs.length, isInitialized, cacheExpiry, loadNFTData]);

  // Listen for wallet changes from MetaMask
  useEffect(() => {
    const handleWalletChange = (event: Event) => {
      const customEvent = event as CustomEvent;
      const newAddress = customEvent.detail?.address;
      
      console.log('🔄 [NFTContext] Wallet changed event received:', newAddress);
      console.log('🧹 [NFTContext] Clearing all NFT data for wallet change...');
      
      // Clear all state immediately
      setAllNFTs([]);
      setOffchainNFTs([]);
      setOnchainNFTs([]);
      setIsInitialized(false);
      setCacheExpiry(null);
      setLastWalletAddress(null);
      setBackupState([]);
      setHasOptimisticUpdates(false);
      
      // Clear session storage
      sessionStorage.removeItem('nft_cache');
      sessionStorage.removeItem('nft_cache_wallet');
      sessionStorage.removeItem('nft_cache_expiry');
      
      // The useEffect with walletAddress dependency will automatically trigger reload
      console.log('✅ [NFTContext] NFT state cleared, waiting for auto-reload...');
    };

    window.addEventListener('wallet-changed', handleWalletChange);
    
    return () => {
      window.removeEventListener('wallet-changed', handleWalletChange);
    };
  }, []);

  // Listen for chain changes and reload onchain NFTs automatically (optimized)
  useEffect(() => {
    console.log('🔗 [NFTContext] Setting up chain change listener...');
    
    const unsubscribe = chainManager.onChainChange((newChain) => {
      console.log(`🔄 [NFTContext] Chain changed to: ${newChain.name}`);
      console.log(`🔄 [NFTContext] NFT Contract: ${newChain.contracts?.nftContract}`);
      console.log(`🔄 [NFTContext] Staking Contract: ${newChain.contracts?.stakingContract}`);
      
      // 🌐 MULTICHAIN OPTIMIZATION: Since MultichainNFTLoader loads NFTs from ALL chains,
      // we don't need to reload NFTs when switching networks - they're already loaded!
      console.log('🌐 [NFTContext] Network switched - no reload needed (multichain NFTs already loaded)');
    });
    
    return () => {
      console.log('🧹 [NFTContext] Cleaning up chain change listener...');
      unsubscribe();
    };
  }, [walletAddress, isAuthenticated, allNFTs.length, onchainNFTs.length, loadNFTData]);

  // Force reload function
  const forceReloadNFTs = useCallback(async () => {
    console.log('🔄 [NFTContext] Force reloading NFTs...');
    setIsLoading(true);
    setIsInitialized(false);
    setAllNFTs([]);
    setOffchainNFTs([]);
    setOnchainNFTs([]);
    setCacheExpiry(null);
    setBackupState([]);
    setHasOptimisticUpdates(false);
    
    // Clear cache
    sessionStorage.removeItem('nft_cache');
    sessionStorage.removeItem('nft_cache_wallet');
    sessionStorage.removeItem('nft_cache_expiry');
    
    await loadNFTData();
  }, [loadNFTData]);

  // Ensure NFTs loaded function
  const ensureNFTsLoaded = useCallback(async () => {
    if (!isAuthenticated || !walletAddress) {
      console.log('⚠️ [NFTContext] Cannot load NFTs - not authenticated');
      return;
    }

    const hasData = allNFTs.length > 0;
    const isCurrentlyLoading = isLoading;
    
    console.log('🔍 [NFTContext] Ensuring NFTs loaded:', { 
      hasData, 
      isCurrentlyLoading, 
      isInitialized,
      walletAddress: walletAddress.slice(0, 8) + '...'
    });

    if (!hasData && !isCurrentlyLoading && !isInitialized) {
      console.log('🚀 [NFTContext] No data found, triggering load...');
      setIsLoading(true);
      await loadNFTData();
    }
  }, [isAuthenticated, walletAddress, allNFTs.length, isLoading, isInitialized, loadNFTData]);

  // Debounced refresh function
  const refreshNFTs = useCallback(async () => {
    console.log('🔄 [NFTContext] Refreshing NFTs...');
    setCacheExpiry(null);
    setHasOptimisticUpdates(false); // Don't set to true to avoid triggering auto-reload
    await loadNFTData();
  }, [loadNFTData]);

  // Sync staking status function - refreshes staking data from blockchain/database
  const syncStakingStatus = useCallback(async (forceSync = false) => {
    if (!walletAddress || !isAuthenticated || allNFTs.length === 0) {
      console.log('⚠️ [NFTContext] Cannot sync staking status - missing requirements');
      return;
    }
    
    // Don't sync if we have optimistic updates - unless forced
    if (hasOptimisticUpdates && !forceSync) {
      console.log('⚠️ [NFTContext] Skipping staking status sync - preserving optimistic updates');
      return;
    }
    
    try {
      console.log('🔄 [NFTContext] Syncing staking status from blockchain/database...');
      
      // 1. Fetch fresh staked NFTs from offchain database
      const offchainStaked = await offChainStakingService.getStakedNFTs(walletAddress);
      console.log(`📊 [NFTContext] Offchain staked NFTs:`, offchainStaked);
      
      // 2. Fetch fresh staked NFTs from onchain (blockchain)
      let onchainStaked: any[] = [];
      try {
        const isOnchainAvailable = await improvedOnchainStakingService.isOnChainAvailable();
        if (isOnchainAvailable) {
          onchainStaked = await improvedOnchainStakingService.getStakedNFTsOnChain(walletAddress);
          console.log(`⛓️ [NFTContext] Onchain staked NFTs:`, onchainStaked);
        }
      } catch (onchainError) {
        console.warn('⚠️ [NFTContext] Failed to fetch onchain staked NFTs:', onchainError);
      }
      
      // 3. Create sets of staked NFT IDs for quick lookup
      const offchainStakedIds = new Set(
        offchainStaked.map(nft => nft.id || nft.nft_id)
      );
      const onchainStakedIds = new Set(
        onchainStaked.map(nft => `onchain_${nft.tokenId}` || `staked_${nft.tokenId}`)
      );
      
      console.log('🔍 [NFTContext] Staked IDs:', {
        offchain: Array.from(offchainStakedIds),
        onchain: Array.from(onchainStakedIds)
      });
      
      // 4. Update allNFTs with fresh staking status
      setAllNFTs(prev => {
        const updated = prev.map(nft => {
          // Check if this NFT is staked offchain
          const isOffchainStaked = offchainStakedIds.has(nft.id);
          
          // Check if this NFT is staked onchain (check multiple ID formats)
          const isOnchainStaked = onchainStakedIds.has(nft.id) || 
                                 onchainStakedIds.has(`onchain_${nft.tokenId}`) ||
                                 onchainStakedIds.has(`staked_${nft.tokenId}`);
          
          const isStaked = isOffchainStaked || isOnchainStaked;
          const stakingSource = isOffchainStaked ? 'offchain' : 
                              isOnchainStaked ? 'onchain' : 'none';
          
          // Only update if staking status changed
          if (nft.isStaked !== isStaked || nft.stakingSource !== stakingSource) {
            console.log(`🔄 [NFTContext] Updating staking status for ${nft.id}:`, {
              was: { isStaked: nft.isStaked, source: nft.stakingSource },
              now: { isStaked, source: stakingSource }
            });
            
            return {
              ...nft,
              isStaked,
              stakingSource: stakingSource as 'none' | 'offchain' | 'onchain',
              stakeTimestamp: isStaked ? (nft.stakeTimestamp || Date.now()) : undefined,
              lastUpdated: Date.now()
            };
          }
          
          return nft;
        });
        
        console.log('✅ [NFTContext] Staking status synced successfully');
        return updated;
      });
      
    } catch (error) {
      console.error('❌ [NFTContext] Failed to sync staking status:', error);
    }
  }, [walletAddress, isAuthenticated, allNFTs.length]);


  const contextValue: NFTContextState = {
    // Auth State
    isAuthenticated,
    walletAddress,
    
    // Data
    allNFTs,
    offchainNFTs,
    onchainNFTs,
    
    // Filtered Views
    availableNFTs,
    stakableNFTs,
    stakedNFTs,
    
    // States
    isLoading,
    isInitialized,
    lastUpdated,
    
    // Streaming Loading States
    isLoadingMore,
    hasMoreToLoad,
    loadingProgress,
    
    // Actions
    loadNFTData,
    refreshNFTs,
    forceReloadNFTs,
    ensureNFTsLoaded,
    syncStakingStatus,
    
    // Optimistic Updates
    updateNFTOptimistically,
    batchUpdateNFTs,
    optimisticStake,
    optimisticUnstake,
    optimisticBurn,
    optimisticClaimStart,
    optimisticClaim,
    
    // Claiming Functions
    handleSuccessfulClaim,
    revertOptimisticUpdate,
    clearOptimisticUpdates,
    confirmDatabaseSync,
    
    // NFT Count Sync
    syncNFTCountsToBackend,
  };

  return (
    <NFTContext.Provider value={contextValue}>
      {children}
    </NFTContext.Provider>
  );
};

export default NFTProvider;
