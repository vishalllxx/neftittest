/**
 * Chain Validation Utilities for NFT Claiming
 * Prevents users from claiming NFTs to the wrong blockchain
 */

import { ChainConfig, getChainByNetwork, SUPPORTED_CHAINS } from '@/config/chains';
import { chainManager } from '@/services/ChainManagerService';
import { supabase } from '@/lib/supabase';
import { toast } from 'sonner';

export interface NFTChainValidation {
  canClaim: boolean;
  assignedChain: string | null;
  currentChain: string;
  needsSwitch: boolean;
  targetChainConfig: ChainConfig | null;
  error?: string;
}

/**
 * Validate if NFT can be claimed to the current blockchain
 */
export async function validateNFTChainForClaim(
  nftId: string,
  nftCid?: string,
  assignedChain?: string
): Promise<NFTChainValidation> {
  const currentChain = chainManager.getCurrentChain();
  
  // If NFT already has assigned_chain from distribution
  if (assignedChain) {
    const canClaimHere = assignedChain === currentChain.network;
    const targetChainConfig = getChainByNetwork(assignedChain);
    
    return {
      canClaim: canClaimHere,
      assignedChain,
      currentChain: currentChain.network,
      needsSwitch: !canClaimHere,
      targetChainConfig,
      error: canClaimHere ? undefined : `This NFT can only be claimed on ${targetChainConfig?.name || assignedChain}`
    };
  }
  
  // If NFT has CID, check with database
  if (nftCid) {
    try {
      const { data, error } = await supabase.rpc('can_claim_nft_to_chain', {
        nft_cid: nftCid,
        target_claim_chain: currentChain.network
      });
      
      if (error) {
        console.error('Chain validation error:', error);
        // Allow claim if validation fails (backward compatibility)
        return {
          canClaim: true,
          assignedChain: null,
          currentChain: currentChain.network,
          needsSwitch: false,
          targetChainConfig: null
        };
      }
      
      const validationData = data as any;
      const assigned = validationData.assigned_chain;
      const targetChainConfig = assigned ? getChainByNetwork(assigned) : null;
      
      return {
        canClaim: validationData.can_claim || false,
        assignedChain: assigned,
        currentChain: currentChain.network,
        needsSwitch: !validationData.can_claim && !!assigned,
        targetChainConfig,
        error: validationData.can_claim ? undefined : validationData.error
      };
    } catch (err) {
      console.error('Exception during chain validation:', err);
      // Allow claim if validation fails (backward compatibility)
      return {
        canClaim: true,
        assignedChain: null,
        currentChain: currentChain.network,
        needsSwitch: false,
        targetChainConfig: null
      };
    }
  }
  
  // No chain assignment - allow claim to any chain
  return {
    canClaim: true,
    assignedChain: null,
    currentChain: currentChain.network,
    needsSwitch: false,
    targetChainConfig: null
  };
}

/**
 * Get chain display name for UI
 */
export function getChainDisplayName(networkOrChainId: string | number): string {
  let chain: ChainConfig | undefined;
  
  if (typeof networkOrChainId === 'string') {
    chain = getChainByNetwork(networkOrChainId);
  } else {
    chain = Object.values(SUPPORTED_CHAINS).find(c => c.chainId === networkOrChainId);
  }
  
  return chain?.name || 'Unknown Chain';
}

/**
 * Get chain icon URL for UI
 */
export function getChainIconUrl(networkOrChainId: string | number): string | undefined {
  let chain: ChainConfig | undefined;
  
  if (typeof networkOrChainId === 'string') {
    chain = getChainByNetwork(networkOrChainId);
  } else {
    chain = Object.values(SUPPORTED_CHAINS).find(c => c.chainId === networkOrChainId);
  }
  
  return chain?.iconUrl;
}

/**
 * Record NFT claim to blockchain in database
 */
export async function recordNFTClaimToChain(
  nftCid: string,
  claimedChain: string,
  contractAddress: string,
  tokenId: string,
  transactionHash: string
): Promise<boolean> {
  try {
    const { data, error } = await supabase.rpc('record_nft_claim_to_chain', {
      nft_cid: nftCid,
      claimed_chain: claimedChain,
      contract_address: contractAddress,
      token_id: tokenId,
      transaction_hash: transactionHash
    });
    
    if (error) {
      console.error('Error recording claim:', error);
      return false;
    }
    
    return data?.success || false;
  } catch (err) {
    console.error('Exception recording claim:', err);
    return false;
  }
}

/**
 * Show chain switch prompt with auto-switch option
 */
export async function promptChainSwitch(
  targetChainConfig: ChainConfig,
  autoSwitch: boolean = true
): Promise<boolean> {
  if (!autoSwitch) {
    toast.error(`Please switch to ${targetChainConfig.name} to claim this NFT`);
    return false;
  }
  
  try {
    toast.info(`Switching to ${targetChainConfig.name}...`);
    
    // Use chainManager to switch chains (chainIdHex is string format)
    await chainManager.switchChain(targetChainConfig.chainIdHex);
    
    toast.success(`Switched to ${targetChainConfig.name}`);
    return true;
  } catch (error: any) {
    console.error('Chain switch error:', error);
    toast.error(`Failed to switch to ${targetChainConfig.name}. Please switch manually.`);
    return false;
  }
}

/**
 * Get chain badge color class for UI
 */
export function getChainBadgeColor(network: string): string {
  const colorMap: Record<string, string> = {
    'polygon-amoy': 'bg-purple-500/20 text-purple-400 border-purple-500/40',
    'sepolia': 'bg-blue-500/20 text-blue-400 border-blue-500/40',
    'bsc-testnet': 'bg-yellow-500/20 text-yellow-400 border-yellow-500/40',
    'avalanche-fuji': 'bg-red-500/20 text-red-400 border-red-500/40',
    'arbitrum-sepolia': 'bg-cyan-500/20 text-cyan-400 border-cyan-500/40',
    'optimism-sepolia': 'bg-pink-500/20 text-pink-400 border-pink-500/40',
    'base-sepolia': 'bg-indigo-500/20 text-indigo-400 border-indigo-500/40'
  };
  
  return colorMap[network] || 'bg-gray-500/20 text-gray-400 border-gray-500/40';
}
