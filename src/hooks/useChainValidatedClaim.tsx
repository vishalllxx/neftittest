/**
 * Hook for NFT claiming with chain validation
 * Prevents users from claiming NFTs to the wrong blockchain
 */

import { useState } from 'react';
import { toast } from 'sonner';
import { chainManager } from '@/services/ChainManagerService';
import {
  validateNFTChainForClaim,
  promptChainSwitch,
  recordNFTClaimToChain,
  getChainDisplayName,
  NFTChainValidation
} from '@/utils/chainValidation';
import { useNFTOperations } from './useNFTOperations';
import { ContextNFT } from '@/contexts/NFTContext';

export interface ChainValidatedClaimResult {
  success: boolean;
  message?: string;
  data?: any;
  validation?: NFTChainValidation;
}

export function useChainValidatedClaim() {
  const { claimNFT } = useNFTOperations();
  const [isValidating, setIsValidating] = useState(false);

  /**
   * Claim NFT with automatic chain validation and switching
   */
  const claimWithValidation = async (
    nft: ContextNFT,
    autoSwitch: boolean = true
  ): Promise<ChainValidatedClaimResult> => {
    setIsValidating(true);

    try {
      // Step 1: Validate chain compatibility
      console.log('🔍 Validating chain for NFT:', {
        id: nft.id,
        name: nft.name,
        assigned_chain: nft.assigned_chain,
        ipfs_cid: nft.ipfs_cid || nft.ipfs_hash,
        can_claim_to_any_chain: nft.can_claim_to_any_chain
      });

      const validation = await validateNFTChainForClaim(
        nft.id,
        nft.ipfs_cid || nft.ipfs_hash,
        nft.assigned_chain
      );

      console.log('✅ Chain validation result:', validation);

      // Step 2: Check if can claim to current chain
      if (!validation.canClaim) {
        if (validation.needsSwitch && validation.targetChainConfig) {
          // Show which chain is required
          const targetChainName = validation.targetChainConfig.name;
          const currentChainName = getChainDisplayName(validation.currentChain);

          console.log(`⚠️ Chain mismatch: Need ${targetChainName}, connected to ${currentChainName}`);

          // Prompt to switch chains
          toast.error(
            <div>
              <strong>Wrong Blockchain!</strong>
              <div className="mt-1 text-sm">
                This NFT can only be claimed to <strong>{targetChainName}</strong>
              </div>
              <div className="text-xs text-gray-400 mt-1">
                Currently connected to {currentChainName}
              </div>
            </div>,
            { duration: 5000 }
          );

          if (autoSwitch) {
            // Attempt automatic chain switch
            const switched = await promptChainSwitch(validation.targetChainConfig, true);

            if (!switched) {
              return {
                success: false,
                message: `Failed to switch to ${targetChainName}. Please switch manually and try again.`,
                validation
              };
            }

            // Wait a bit for chain switch to complete
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Re-validate after switch
            const revalidation = await validateNFTChainForClaim(
              nft.id,
              nft.ipfs_cid || nft.ipfs_hash,
              nft.assigned_chain
            );

            if (!revalidation.canClaim) {
              return {
                success: false,
                message: `Still cannot claim after switching. Please ensure you're on ${targetChainName}.`,
                validation: revalidation
              };
            }
          } else {
            return {
              success: false,
              message: validation.error || `This NFT can only be claimed on ${targetChainName}`,
              validation
            };
          }
        } else {
          // Generic error
          return {
            success: false,
            message: validation.error || 'Cannot claim NFT to current blockchain',
            validation
          };
        }
      }

      // Step 3: Proceed with claiming
      const currentChain = chainManager.getCurrentChain();
      console.log(`✅ Chain validated - claiming to ${currentChain.name}`);

      // Create loading toast with ID so we can dismiss it later
      const claimToastId = `claim-${nft.id}`;
      toast.loading(`Claiming ${nft.name} to ${currentChain.name}...`, {
        id: claimToastId
      });

      try {
        const result = await claimNFT(nft.id);

        // Dismiss the loading toast after claim completes
        toast.dismiss(claimToastId);

        if (!result.success) {
          return {
            success: false,
            message: result.message || 'Failed to claim NFT',
            validation
          };
        }

        // Step 4: Record claim in database (if CID available)
        const cid = nft.ipfs_cid || nft.ipfs_hash;
        if (cid && result.data?.onchainNFT) {
          const onchainNFT = result.data.onchainNFT;
          
          console.log('📝 Recording claim to database:', {
            cid,
            chain: currentChain.network,
            contract: onchainNFT.contractAddress,
            tokenId: onchainNFT.tokenId,
            txHash: onchainNFT.transactionHash
          });

          const recorded = await recordNFTClaimToChain(
            cid,
            currentChain.network,
            onchainNFT.contractAddress || currentChain.contracts?.nftContract || '',
            onchainNFT.tokenId?.toString() || '',
            onchainNFT.transactionHash || ''
          );

          if (recorded) {
            console.log('✅ Claim recorded in database');
          } else {
            console.warn('⚠️ Failed to record claim in database (non-critical)');
          }
        }

        return {
          success: true,
          message: result.message,
          data: result.data,
          validation
        };
      } catch (claimError: any) {
        // Ensure loading toast is dismissed on error
        toast.dismiss(claimToastId);
        throw claimError;
      }

    } catch (error: any) {
      console.error('❌ Chain validated claim error:', error);
      return {
        success: false,
        message: error.message || 'Failed to claim NFT with chain validation'
      };
    } finally {
      setIsValidating(false);
    }
  };

  /**
   * Check if NFT can be claimed to current chain (without claiming)
   */
  const checkChainCompatibility = async (nft: ContextNFT): Promise<NFTChainValidation> => {
    return validateNFTChainForClaim(
      nft.id,
      nft.ipfs_cid || nft.ipfs_hash,
      nft.assigned_chain
    );
  };

  return {
    claimWithValidation,
    checkChainCompatibility,
    isValidating
  };
}
