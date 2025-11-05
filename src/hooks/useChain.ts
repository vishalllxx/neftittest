/**
 * React Hook for Chain Management
 * Provides easy access to current chain and chain switching functionality
 */

import { useState, useEffect } from 'react';
import { chainManager } from '../services/ChainManagerService';
import type { ChainConfig } from '../config/chains';

interface UseChainReturn {
  currentChain: ChainConfig;
  isCorrectNetwork: boolean;
  isSwitching: boolean;
  switchChain: (chainKey: string) => Promise<void>;
  getContractAddresses: () => { nftContract?: string; stakingContract?: string };
  getBlockExplorerUrl: () => string;
  getTxUrl: (txHash: string) => string;
  getAddressUrl: (address: string) => string;
  hasContracts: boolean;
}

export function useChain(): UseChainReturn {
  const [currentChain, setCurrentChain] = useState<ChainConfig>(chainManager.getCurrentChain());
  const [isCorrectNetwork, setIsCorrectNetwork] = useState(true);
  const [isSwitching, setIsSwitching] = useState(false);

  useEffect(() => {
    // Listen for chain changes
    const unsubscribe = chainManager.onChainChange((newChain) => {
      setCurrentChain(newChain);
    });

    // Check if wallet is on correct network
    checkNetwork();

    // Check network periodically
    const interval = setInterval(checkNetwork, 5000);

    return () => {
      unsubscribe();
      clearInterval(interval);
    };
  }, []);

  const checkNetwork = async () => {
    try {
      const isCorrect = await chainManager.isOnCorrectNetwork();
      setIsCorrectNetwork(isCorrect);
    } catch (error) {
      console.error('Failed to check network:', error);
    }
  };

  const switchChain = async (chainKey: string) => {
    setIsSwitching(true);
    try {
      await chainManager.switchChain(chainKey);
      await checkNetwork();
    } finally {
      setIsSwitching(false);
    }
  };

  return {
    currentChain,
    isCorrectNetwork,
    isSwitching,
    switchChain,
    getContractAddresses: () => chainManager.getContractAddresses(),
    getBlockExplorerUrl: () => chainManager.getBlockExplorerUrl(),
    getTxUrl: (txHash: string) => chainManager.getTxUrl(txHash),
    getAddressUrl: (address: string) => chainManager.getAddressUrl(address),
    hasContracts: chainManager.hasContractsConfigured(),
  };
}
