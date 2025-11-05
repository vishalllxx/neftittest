/**
 * useAutoChainSwitch Hook
 * Automatically switches to the required chain for NFT operations (claim/stake/burn)
 */

import { useCallback } from 'react';
import { chainManager } from '@/services/ChainManagerService';
import { SUPPORTED_CHAINS, getChainByNetwork } from '@/config/chains';
import { toast } from 'sonner';

// Map network identifiers to SUPPORTED_CHAINS keys
const NETWORK_TO_CHAIN_KEY: Record<string, string> = {
  'sepolia': 'SEPOLIA',
  'polygon-amoy': 'POLYGON_AMOY',
  'bsc-testnet': 'BSC_TESTNET',
  'arbitrum-sepolia': 'ARBITRUM_SEPOLIA',
  'optimism-sepolia': 'OPTIMISM_SEPOLIA',
  'base-sepolia': 'BASE_SEPOLIA',
  'avalanche-fuji': 'AVALANCHE_FUJI',
};

export interface AutoChainSwitchResult {
  success: boolean;
  message?: string;
  cancelled?: boolean;
}

export const useAutoChainSwitch = () => {
  /**
   * Extract chain from NFT attributes with enhanced offchain support
   */
  const getChainFromNFT = useCallback((nft: any): string | null => {
    const logContext = {
      nftId: nft.id,
      status: nft.status,
      type: nft.type,
      blockchain: nft.blockchain,
      claimed_blockchain: nft.claimed_blockchain,
      hasAttributes: !!nft.attributes,
      attributesCount: Array.isArray(nft.attributes) ? nft.attributes.length : 0,
      isOffchain: nft.status === 'offchain' || nft.type === 'offchain'
    };

    console.log('🔍 [AutoChainSwitch] Analyzing NFT:', logContext);

    // 1. Check direct chain properties first (highest priority)
    const directChain = nft.blockchain || nft.claimed_blockchain || nft.chain;
    if (directChain) {
      console.log(`✅ [AutoChainSwitch] Found direct chain property: ${directChain}`);
      return directChain.toLowerCase();
    }

    // 2. For offchain NFTs, check various possible attribute locations
    if (logContext.isOffchain) {
      console.log('🔄 [AutoChainSwitch] Processing offchain NFT, checking attributes...');
      
      // Try different attribute locations and formats
      const possibleChainSources = [
        // Direct attributes
        nft.assigned_chain,
        nft.chain,
        nft.network,
        // Nested in metadata
        nft.metadata?.chain,
        nft.metadata?.network,
        nft.attributes?.chain,
        nft.attributes?.network,
        // Find in attributes array
        ...(Array.isArray(nft.attributes) 
          ? nft.attributes
              .filter(attr => ['chain', 'network', 'assigned_chain'].includes(attr.trait_type?.toLowerCase()))
              .map(attr => attr.value)
          : [])
      ].filter(Boolean);

      console.log('🔍 [AutoChainSwitch] Possible chain sources:', possibleChainSources);

      // Process the first valid chain source found
      for (const source of possibleChainSources) {
        if (!source) continue;
        
        const normalizedSource = String(source).toLowerCase().trim();
        console.log(`🔍 [AutoChainSwitch] Checking chain source: ${normalizedSource}`);

        // Map common chain names to our network identifiers
        const chainMappings: [string, string][] = [
          ['ethereum', 'sepolia'],
          ['polygon', 'polygon-amoy'],
          ['bsc', 'bsc-testnet'],
          ['binance', 'bsc-testnet'],
          ['avalanche', 'avalanche-fuji'],
          ['avax', 'avalanche-fuji'],
          ['optimism', 'optimism-sepolia'],
          ['arbitrum', 'arbitrum-sepolia'],
          ['base', 'base-sepolia']
        ];

        for (const [key, value] of chainMappings) {
          if (normalizedSource.includes(key)) {
            console.log(`✅ [AutoChainSwitch] Mapped '${normalizedSource}' to: ${value}`);
            return value;
          }
        }
      }

      // Fallback to default chain if no chain detected
      const defaultChain = 'polygon-amoy'; // Default fallback chain
      console.warn(`⚠️ [AutoChainSwitch] No chain detected, using default: ${defaultChain}`);
      return defaultChain;
    }

    // 3. For onchain NFTs, we must have a chain
    if (nft.status === 'onchain') {
      console.warn('❌ [AutoChainSwitch] Onchain NFT missing required chain information');
      return null;
    }

    // 4. If we get here, log detailed debug info
    console.warn('❌ [AutoChainSwitch] Could not determine chain for NFT:', {
      ...logContext,
      availableKeys: Object.keys(nft),
      sampleAttributes: Array.isArray(nft.attributes) 
        ? nft.attributes.slice(0, 3) 
        : 'Not an array'
    });
    
    return null;
  }, []);

  /**
   * Check if already on the correct chain
   */
  const isOnCorrectChain = useCallback((networkIdentifier: string): boolean => {
    const currentChain = chainManager.getCurrentChain();
    return currentChain.network === networkIdentifier;
  }, []);

  /**
   * Switch to required chain for NFT operation with enhanced error handling
   */
  const switchToNFTChain = useCallback(async (
    nft: any,
    operationType: 'claim' | 'stake' | 'burn' = 'claim'
  ): Promise<AutoChainSwitchResult> => {
    // Generate a unique operation ID for tracking
    const operationId = Math.random().toString(36).substring(2, 8);
    
    const log = (message: string, data?: any) => {
      console.log(`[${operationId}] ${message}`, data || '');
    };

    try {
      log(`🔄 Starting chain switch for ${operationType} operation`);
      log('NFT details:', { 
        id: nft.id, 
        name: nft.name,
        status: nft.status,
        type: nft.type 
      });
      
      // Extract chain from NFT with detailed logging
      log('🔍 Attempting to detect chain from NFT...');
      const networkIdentifier = getChainFromNFT(nft);

      if (!networkIdentifier) {
        const errorMsg = 'Could not determine which chain this NFT belongs to';
        log('❌ ' + errorMsg, nft);
        toast.error('Chain Detection Failed', {
          description: 'We could not determine which blockchain this NFT belongs to. Please try again or contact support.'
        });
        return { success: false, message: errorMsg };
      }

      log(`✅ Detected target chain: ${networkIdentifier}`);

      // Check if already on correct chain
      if (isOnCorrectChain(networkIdentifier)) {
        log('✅ Already on the correct chain - no switch needed');
        return { success: true };
      }

      const currentChain = chainManager.getCurrentChain();
      log(`🔄 Need to switch from ${currentChain.network} to ${networkIdentifier}`);

      // Get chain config with validation
      log('🔍 Looking up chain configuration...');
      const chainConfig = getChainByNetwork(networkIdentifier);
      if (!chainConfig) {
        const errorMsg = `Chain ${networkIdentifier} not found in configuration`;
        log('❌ ' + errorMsg);
        toast.error('Unsupported Network', {
          description: `The blockchain network '${networkIdentifier}' is not supported.`
        });
        return { success: false, message: errorMsg };
      }

      // Get chain key for switching with validation
      log('🔑 Looking up chain key for switching...');
      const chainKey = NETWORK_TO_CHAIN_KEY[networkIdentifier];
      if (!chainKey) {
        const errorMsg = `Chain key not found for network: ${networkIdentifier}`;
        log('❌ ' + errorMsg, { networkIdentifier, availableKeys: Object.keys(NETWORK_TO_CHAIN_KEY) });
        toast.error('Configuration Error', {
          description: 'This blockchain network is not properly configured. Please try another network or contact support.'
        });
        return { success: false, message: errorMsg };
      }
      log(`🔑 Found chain key: ${chainKey}`);

      // Show loading toast
      const loadingToastId = `chain-switch-${Date.now()}`;
      toast.loading(
        `Switching to ${chainConfig.name} for ${operationType}...`,
        { 
          id: loadingToastId,
          duration: Infinity 
        }
      );

      try {
        log(`🔄 Attempting to switch to chain: ${chainKey} (${chainConfig.name})`);
        
        // Attempt to switch chain
        await chainManager.switchChain(chainKey);
        
        // Verify the switch was successful
        const newChain = chainManager.getCurrentChain();
        if (newChain.network !== networkIdentifier) {
          throw new Error(`Failed to switch to ${networkIdentifier}. Current chain: ${newChain.network}`);
        }
        
        log(`✅ Successfully switched to ${chainConfig.name}`);
        
        // Update the loading toast to success
        toast.success(`Connected to ${chainConfig.name}`, {
          id: loadingToastId,
          description: 'You can now proceed with your transaction.'
        });
        
        return { 
          success: true,
          message: `Successfully switched to ${chainConfig.name}`
        };
        
      } catch (error: any) {
        const isUserRejected = error?.code === 4001 || error?.message?.toLowerCase().includes('reject');
        const errorMessage = isUserRejected 
          ? 'Network switch was cancelled' 
          : error.message || 'Failed to switch network';
          
        log(`❌ Error switching to ${chainConfig.name}:`, error);
        
        if (isUserRejected) {
          toast.warning('Network Switch Cancelled', {
            id: loadingToastId,
            description: 'You need to switch networks to complete this action.'
          });
        } else {
          toast.error('Network Switch Failed', {
            id: loadingToastId,
            description: errorMessage + '. Please try again or switch networks manually in your wallet.'
          });
        }

        return {
          success: false,
          message: errorMessage,
          cancelled: isUserRejected
        };
      }
    } catch (error: any) {
      console.error('Error in switchToNFTChain:', error);
      return {
        success: false,
        message: error.message || 'Unknown error during chain switch',
      };
    }
  }, [getChainFromNFT, isOnCorrectChain]);

  /**
   * Switch to required chain for multiple NFTs (for batch operations)
   * Ensures all NFTs are on the same chain
   * 
   * Special handling for BURN operations:
   * - Offchain NFTs: No chain switching needed (burn from database)
   * - Onchain NFTs: Must be on same chain, switch to that chain
   * - Mixed: Allow mixed burns, only switch chain for onchain NFTs
   */
  const switchToNFTsChain = useCallback(async (
    nfts: any[],
    operationType: 'claim' | 'stake' | 'burn' = 'claim'
  ): Promise<AutoChainSwitchResult> => {
    console.log(`🔄 [AutoChainSwitch] switchToNFTsChain called for ${nfts.length} NFT(s) - operation: ${operationType}`);
    
    if (nfts.length === 0) {
      console.warn('❌ [AutoChainSwitch] No NFTs provided');
      return {
        success: false,
        message: 'No NFTs provided',
      };
    }
    
    console.log('🔍 [AutoChainSwitch] NFTs to process:', nfts.map(nft => ({
      id: nft.id,
      status: nft.status,
      blockchain: nft.blockchain
    })));

    // Special handling for BURN operations
    if (operationType === 'burn') {
      // Separate offchain and onchain NFTs
      const offchainNFTs = nfts.filter(nft => nft.status === 'offchain');
      const onchainNFTs = nfts.filter(nft => nft.status === 'onchain');

      console.log(`🔍 Burn chain validation: ${offchainNFTs.length} offchain, ${onchainNFTs.length} onchain NFTs`);

      // If all NFTs are offchain, no chain switching needed
      if (onchainNFTs.length === 0) {
        console.log('✅ All NFTs are offchain - no chain switching required');
        return { success: true };
      }

      // If we have onchain NFTs, allow multi-chain burns
      if (onchainNFTs.length > 0) {
        const onchainChains = onchainNFTs.map(nft => getChainFromNFT(nft)).filter(Boolean);
        const uniqueOnchainChains = [...new Set(onchainChains)];

        if (uniqueOnchainChains.length === 0) {
          return {
            success: false,
            message: 'Could not determine chain for onchain NFTs',
          };
        }

        // Multi-chain onchain burns are now supported!
        if (uniqueOnchainChains.length > 1) {
          console.log(`🌐 Multi-chain burn detected: ${uniqueOnchainChains.join(', ')}`);
          console.log(`⚡ Will burn NFTs sequentially on each chain`);
          // Return success - the burn service will handle chain switching per group
          return { 
            success: true,
            message: `Multi-chain burn: ${uniqueOnchainChains.length} chains (${uniqueOnchainChains.join(', ')})`
          };
        }

        // Single chain - switch to it
        console.log(`🔄 Switching to ${uniqueOnchainChains[0]} for onchain NFT burning...`);
        return await switchToNFTChain(onchainNFTs[0], operationType);
      }

      // Should never reach here, but return success as fallback
      return { success: true };
    }

    // For non-burn operations (claim/stake), use original logic
    console.log(`🔍 [AutoChainSwitch] Processing ${operationType} operation for ${nfts.length} NFT(s)`);
    
    // Get chains for all NFTs
    const chains = nfts.map(nft => getChainFromNFT(nft)).filter(Boolean);
    const uniqueChains = [...new Set(chains)];

    console.log('🔍 [AutoChainSwitch] Chain detection results:', {
      totalNFTs: nfts.length,
      chainsDetected: chains,
      uniqueChains
    });

    // Check if all NFTs are on the same chain
    if (uniqueChains.length > 1) {
      console.warn(`❌ [AutoChainSwitch] Multiple chains detected: ${uniqueChains.join(', ')}`);
      return {
        success: false,
        message: `Selected NFTs are on different chains: ${uniqueChains.join(', ')}. Please select NFTs from the same chain.`,
      };
    }

    if (uniqueChains.length === 0) {
      console.warn('❌ [AutoChainSwitch] No chain could be determined for any NFT');
      return {
        success: false,
        message: 'Could not determine chain for selected NFTs',
      };
    }

    console.log(`✅ [AutoChainSwitch] All NFTs on same chain: ${uniqueChains[0]}, switching...`);
    
    // Switch to the required chain using the first NFT
    return await switchToNFTChain(nfts[0], operationType);
  }, [getChainFromNFT, switchToNFTChain]);

  return {
    switchToNFTChain,
    switchToNFTsChain,
    getChainFromNFT,
    isOnCorrectChain,
  };
};
