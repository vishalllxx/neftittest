import { useState, useEffect } from 'react';
import { enhancedHybridBurnService } from '@/services/EnhancedHybridBurnService';
import type { NFTData } from '@/services/HybridIPFSService';
import toast from 'react-hot-toast';

// Extended NFT type with staking status (matches Burn.tsx)
interface NFTWithStatus extends NFTData {
  isStaked?: boolean;
  status?: 'offchain' | 'onchain' | 'claiming';
  blockchain_network?: string;
}

interface BalanceCheckResult {
  isChecking: boolean;
  hasSufficientBalance: boolean;
  insufficientChains: string[];
  errorMessage: string | null;
}

/**
 * Hook to automatically check gas balance when NFTs are selected
 * Only checks balance for onchain NFTs
 */
export function useBalanceCheck(selectedNFTs: NFTWithStatus[]): BalanceCheckResult {
  const [isChecking, setIsChecking] = useState(false);
  const [hasSufficientBalance, setHasSufficientBalance] = useState(true);
  const [insufficientChains, setInsufficientChains] = useState<string[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    // Only check if there are onchain NFTs selected
    const onchainNFTs = selectedNFTs.filter(nft => nft.status === 'onchain');
    
    if (onchainNFTs.length === 0) {
      // No onchain NFTs, no balance check needed
      setHasSufficientBalance(true);
      setInsufficientChains([]);
      setErrorMessage(null);
      return;
    }

    let isCancelled = false;

    const checkBalance = async () => {
      setIsChecking(true);
      setErrorMessage(null);

      try {
        // Group NFTs by chain
        const nftsByChain: Record<string, any[]> = {};
        onchainNFTs.forEach(nft => {
          const network = nft.blockchain_network || 'polygon-amoy';
          if (!nftsByChain[network]) {
            nftsByChain[network] = [];
          }
          nftsByChain[network].push(nft);
        });

        console.log('💰 Pre-checking balance for chains:', Object.keys(nftsByChain));

        // Check balance on all chains
        const result = await enhancedHybridBurnService.checkBalanceOnAllChains(nftsByChain);

        if (!isCancelled) {
          setHasSufficientBalance(result.success);
          setInsufficientChains(result.insufficientChains);

          if (!result.success && result.insufficientChains.length > 0) {
            setErrorMessage(`Insufficient balance on ${result.insufficientChains.length} chain(s)`);
          }
        }
      } catch (error) {
        console.error('❌ Balance check failed:', error);
        if (!isCancelled) {
          setHasSufficientBalance(false);
          setErrorMessage('Failed to check balance');
        }
      } finally {
        if (!isCancelled) {
          setIsChecking(false);
        }
      }
    };

    // Add a small delay to avoid checking on every keystroke
    const timeoutId = setTimeout(() => {
      checkBalance();
    }, 500);

    return () => {
      isCancelled = true;
      clearTimeout(timeoutId);
    };
  }, [selectedNFTs]);

  return {
    isChecking,
    hasSufficientBalance,
    insufficientChains,
    errorMessage
  };
}
