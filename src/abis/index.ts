// ABI exports for NEFTIT smart contracts
export { default as NFTStakeABI } from './NFTStake.json';
export { default as ERC721ABI } from './ERC721.json';

// Type definitions for ABIs
export type ContractABI = any[];

// Multi-chain configuration imports
export { SUPPORTED_CHAINS, DEFAULT_CHAIN, AVAILABLE_CHAINS, type ChainConfig } from '../config/chains';

// Import and re-export chainManager
import { chainManager } from '../services/ChainManagerService';
export { chainManager };

// Legacy exports for backward compatibility
// These now dynamically use the current chain from chainManager

/**
 * Get contract addresses for the current active chain
 * @deprecated Use chainManager.getContractAddresses() instead
 */
export const CONTRACT_ADDRESSES = {
  get NFT_CONTRACT(): string {
    // Import chainManager dynamically (already imported at top of file)
    try {
      const contracts = chainManager.getContractAddresses();
      return contracts.nftContract || '';
    } catch (error) {
      console.warn('NFT contract not configured for current chain');
      return '';
    }
  },
  get STAKING_CONTRACT(): string {
    // Import chainManager dynamically (already imported at top of file)
    try {
      const contracts = chainManager.getContractAddresses();
      return contracts.stakingContract || '';
    } catch (error) {
      console.warn('Staking contract not configured for current chain');
      return '';
    }
  },
};

/**
 * Get network configuration for the current active chain
 * @deprecated Use chainManager.getCurrentChain() instead
 */
export const NETWORK_CONFIG = {
  get CHAIN_ID(): number {
    return chainManager.getCurrentChain().chainId;
  },
  get RPC_URL(): string {
    return chainManager.getCurrentChain().rpcUrls[0];
  },
  get NETWORK_NAME(): string {
    return chainManager.getCurrentChain().name;
  },
  get CURRENCY_SYMBOL(): string {
    return chainManager.getCurrentChain().nativeCurrency.symbol;
  },
  get BLOCK_EXPLORER(): string {
    return chainManager.getCurrentChain().blockExplorerUrls[0];
  },
};
