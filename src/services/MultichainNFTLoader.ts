/**
 * Multichain NFT Loader Service
 * Loads NFTs from all supported chains simultaneously WITHOUT switching user's current chain
 */

import Web3 from 'web3';
import { AVAILABLE_CHAINS, ChainConfig } from '@/config/chains';
import { OnchainNFT } from './NFTLifecycleService';

// Simple ERC721 ABI for token queries
const ERC721_ABI = [
  {
    inputs: [{ name: 'owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'owner', type: 'address' }, { name: 'index', type: 'uint256' }],
    name: 'tokenOfOwnerByIndex',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    name: 'tokenURI',
    outputs: [{ name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

// Staking contract ABI for querying staked NFTs
const STAKING_ABI = [
  {
    inputs: [{ name: '_staker', type: 'address' }],
    name: 'getStakeInfo',
    outputs: [
      { name: 'stakedNFTs', type: 'uint256[]' },
      { name: 'totalStaked', type: 'uint256' }
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    name: 'stakes',
    outputs: [
      { name: 'staker', type: 'address' },
      { name: 'timestamp', type: 'uint256' }
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

export class MultichainNFTLoader {
  /**
   * Load NFTs from ALL chains in parallel without switching chains
   */
  async loadAllChainNFTs(walletAddress: string): Promise<OnchainNFT[]> {
    console.log('🌐 [MultichainNFT] Loading NFTs from all chains for:', walletAddress);
    
    // Load from all chains in parallel
    const promises = AVAILABLE_CHAINS.map(chain => 
      this.loadNFTsFromChain(walletAddress, chain)
    );
    
    const results = await Promise.allSettled(promises);
    
    // Combine all successful results
    const allNFTs: OnchainNFT[] = [];
    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        allNFTs.push(...result.value);
        console.log(`✅ [MultichainNFT] Loaded ${result.value.length} NFTs from ${AVAILABLE_CHAINS[index].name}`);
      } else {
        console.warn(`⚠️ [MultichainNFT] Failed to load from ${AVAILABLE_CHAINS[index].name}:`, result.reason);
      }
    });
    console.log(`🌐 [MultichainNFT] Total NFTs loaded from all chains: ${allNFTs.length}`);
    return allNFTs;
  }

  /**
   * Try contract call with RPC endpoint retry
   */
  private async tryContractCallWithRetry(
    rpcUrls: string[],
    contractABI: any,
    contractAddress: string,
    method: string,
    params: any[]
  ): Promise<any> {
    for (let i = 0; i < rpcUrls.length; i++) {
      try {
        const web3 = new Web3(rpcUrls[i]);
        const contract = new web3.eth.Contract(contractABI, contractAddress);
        const result = await contract.methods[method](...params).call();
        return result;
      } catch (error) {
        if (i === rpcUrls.length - 1) {
          throw error; // Throw on last attempt
        }
        // Silently retry with next RPC
      }
    }
    throw new Error('All RPC endpoints failed');
  }

  /**
   * Load NFTs from a specific chain without switching the user's network
   */
  private async loadNFTsFromChain(
    walletAddress: string,
    chain: ChainConfig
  ): Promise<OnchainNFT[]> {
    try {
      const contractAddress = chain.contracts?.nftContract;
      const stakingAddress = chain.contracts?.stakingContract;
      
      if (!contractAddress) {
        console.log(`⚠️ [MultichainNFT] No contract address for ${chain.name}`);
        return [];
      }

      // Create Web3 instance for this chain (without switching user's chain)
      const web3 = new Web3(chain.rpcUrls[0]);
      const nftContract = new web3.eth.Contract(ERC721_ABI, contractAddress);
      
      const allNFTs: OnchainNFT[] = [];

      // 1. Load owned NFTs
      const balance = await nftContract.methods.balanceOf(walletAddress).call();
      const balanceNum = Number(balance);

      console.log(`📊 [MultichainNFT] Found ${balanceNum} owned NFTs on ${chain.name}`);

      const ownedPromises: Promise<OnchainNFT | null>[] = [];
      for (let i = 0; i < balanceNum; i++) {
        ownedPromises.push(this.loadNFTMetadata(nftContract, walletAddress, i, chain, false));
      }

      const ownedNFTs = await Promise.all(ownedPromises);
      allNFTs.push(...ownedNFTs.filter((nft): nft is OnchainNFT => nft !== null));

      // 2. Load staked NFTs (only if staking contract exists and supports getStakeInfo)
      if (stakingAddress) {
        try {
          const stakingContract = new web3.eth.Contract(STAKING_ABI, stakingAddress);
          
          // Call getStakeInfo to get staked NFT token IDs
          // const stakeInfo = await stakingContract.methods.getStakeInfo(walletAddress).call();
          const stakeInfo = await this.tryContractCallWithRetry(
            chain.rpcUrls,
            STAKING_ABI,
            stakingAddress,
            'getStakeInfo',
            [walletAddress]
          );
          const stakedTokenIds = stakeInfo.stakedNFTs || stakeInfo[0]; // Handle both named and indexed return
          
          if (stakedTokenIds && stakedTokenIds.length > 0) {
            console.log(`📊 [MultichainNFT] Found ${stakedTokenIds.length} staked NFTs on ${chain.name}`);

            const stakedPromises: Promise<OnchainNFT | null>[] = [];
            for (const tokenId of stakedTokenIds) {
              stakedPromises.push(this.loadStakedNFTMetadata(nftContract, stakingContract, tokenId, walletAddress, chain));
            }

            const stakedNFTs = await Promise.all(stakedPromises);
            allNFTs.push(...stakedNFTs.filter((nft): nft is OnchainNFT => nft !== null));
          } else {
            console.log(`📊 [MultichainNFT] No staked NFTs found on ${chain.name}`);
          }
        } catch (stakingError: any) {
          // Silently skip if staking contract doesn't exist or doesn't support getStakeInfo
          // This is expected for chains where staking isn't deployed yet
          console.log(`ℹ️ [MultichainNFT] Staking not available on ${chain.name} (contract not deployed or function not supported)`);
        }
      }

      console.log(`✅ [MultichainNFT] Total ${allNFTs.length} NFTs loaded from ${chain.name}`);
      return allNFTs;
      
    } catch (error) {
      console.error(`❌ [MultichainNFT] Error loading from ${chain.name}:`, error);
      return [];
    }
  }

  /**
   * Load metadata for a single NFT
   */
  private async loadNFTMetadata(
    contract: any,
    walletAddress: string,
    index: number,
    chain: ChainConfig,
    isStaked: boolean
  ): Promise<OnchainNFT | null> {
    try {
      // Get token ID
      const tokenId = await contract.methods.tokenOfOwnerByIndex(walletAddress, index).call();
      const tokenIdStr = tokenId.toString();

      // Get token URI
      const tokenURI = await contract.methods.tokenURI(tokenId).call();

      // Fetch metadata
      const metadataUrl = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
      const response = await fetch(metadataUrl);
      const metadata = await response.json();

      // Extract rarity
      let rarity = 'common';
      if (metadata.attributes) {
        const rarityAttr = metadata.attributes.find((attr: any) =>
          attr.trait_type?.toLowerCase() === 'rarity'
        );
        if (rarityAttr) {
          rarity = rarityAttr.value.toLowerCase();
        }
      }

      const nft: OnchainNFT = {
        id: `${chain.network}_${tokenIdStr}`,
        name: metadata.name || `NFT #${tokenIdStr}`,
        description: metadata.description || '',
        image: (metadata.image || '').replace('ipfs://', 'https://ipfs.io/ipfs/'),
        rarity,
        attributes: metadata.attributes || [],
        tokenId: tokenIdStr,
        transactionHash: '',
        contractAddress: chain.contracts?.nftContract || '',
        metadataURI: tokenURI,
        wallet_address: walletAddress,
        claimed_at: new Date().toISOString(),
        claimed_blockchain: chain.network,
        status: 'onchain',
        // Add chain metadata
        blockchain: chain.network,
        chainId: chain.chainId,
        chainName: chain.name,
        chainIconUrl: chain.iconUrl,
        fallback_images: [],
        ipfs_hash: '',
        isStaked,
      };

      return nft;
    } catch (error) {
      console.warn(`⚠️ [MultichainNFT] Failed to load NFT at index ${index} on ${chain.name}:`, error);
      return null;
    }
  }

  /**
   * Load metadata for a staked NFT
   */
  private async loadStakedNFTMetadata(
    nftContract: any,
    stakingContract: any,
    tokenId: any,
    walletAddress: string,
    chain: ChainConfig
  ): Promise<OnchainNFT | null> {
    try {
      const tokenIdStr = tokenId.toString();

      // Skip stake info for now - we already know it's staked from getStakeInfo
      const stakeTimestamp = Date.now(); // Use current timestamp as fallback

      // Get token URI with RPC retry
      const tokenURI = await this.tryContractCallWithRetry(
        chain.rpcUrls,
        ERC721_ABI,
        chain.contracts?.nftContract || '',
        'tokenURI',
        [tokenId]
      );

      // Fetch metadata
      const metadataUrl = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
      const response = await fetch(metadataUrl);
      const metadata = await response.json();

      // Extract rarity
      let rarity = 'common';
      if (metadata.attributes) {
        const rarityAttr = metadata.attributes.find((attr: any) =>
          attr.trait_type?.toLowerCase() === 'rarity'
        );
        if (rarityAttr) {
          rarity = rarityAttr.value.toLowerCase();
        }
      }

      const nft: OnchainNFT = {
        id: `${chain.network}_${tokenIdStr}`,
        name: metadata.name || `NFT #${tokenIdStr}`,
        description: metadata.description || '',
        image: (metadata.image || '').replace('ipfs://', 'https://ipfs.io/ipfs/'),
        rarity,
        attributes: metadata.attributes || [],
        tokenId: tokenIdStr,
        transactionHash: '',
        contractAddress: chain.contracts?.nftContract || '',
        metadataURI: tokenURI,
        wallet_address: walletAddress,
        claimed_at: new Date().toISOString(),
        claimed_blockchain: chain.network,
        status: 'onchain',
        // Add chain metadata
        blockchain: chain.network,
        chainId: chain.chainId,
        chainName: chain.name,
        chainIconUrl: chain.iconUrl,
        fallback_images: [],
        ipfs_hash: '',
        isStaked: true,
        stakeTimestamp,
      };

      return nft;
    } catch (error) {
      console.warn(`⚠️ [MultichainNFT] Failed to load staked NFT ${tokenId} on ${chain.name}:`, error);
      return null;
    }
  }
}

export const multichainNFTLoader = new MultichainNFTLoader();
