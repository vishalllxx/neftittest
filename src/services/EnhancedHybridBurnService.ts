/**
 * Enhanced Hybrid Burn Service - Smart Mixed Onchain/Offchain Burning
 * Handles mixed selections intelligently:
 * - Mixed offchain/onchain of same rarity: burn each type appropriately
 * - Pure onchain: burn onchain, provide result from offchain CID pool
 * - Pure offchain: existing working system
 */

import Web3 from "web3";
import { ERC721ABI, chainManager, CONTRACT_ADDRESSES } from '../abis/index';
import { optimizedCIDPoolBurnService } from './OptimizedCIDPoolBurnService';
import type { BurnResult, BurnRule } from './OptimizedCIDPoolBurnService';
import type { NFTData } from './HybridIPFSService';
import { nftLifecycleService, OffchainNFT, OnchainNFT } from './NFTLifecycleService';
import { getWalletSupabaseClient } from '../lib/supabaseClientManager';
import { getIPFSUrl } from '../config/ipfsConfig';
import toast from 'react-hot-toast';
import { v4 as uuidv4 } from 'uuid';
import type { ChainConfig } from '../config/chains';
import { getChainByNetwork, getChainKeyByNetwork, SUPPORTED_CHAINS } from '../config/chains';

interface NFTWithStatus extends NFTData {
  status: 'offchain' | 'onchain';
  tokenId?: string;
  contractAddress?: string;
  stakingStatus?: 'staked' | 'unstaked';
  isStaked?: boolean;
  blockchain?: string;
  chain?: string;
  claimed_blockchain?: string;
}

interface BurnGroup {
  offchainNFTs: NFTWithStatus[];
  onchainNFTs: NFTWithStatus[];
  rarity: string;
  totalCount: number;
}

interface BurnTransaction {
  hash?: string;
  tokenIds: string[];
  resultRarity: string;
  timestamp: number;
  gasUsed?: string;
  blockNumber?: number;
  burnType: 'hybrid' | 'onchain' | 'offchain';
}

class EnhancedHybridBurnService {
  private web3: Web3 | null = null;
  private nftContract: any = null;
  private userAccount: string | null = null;
  private currentChain: ChainConfig;
  private chainChangeUnsubscribe?: () => void;
  private readonly BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";
  private selectedProvider: any = null; // Store the selected MetaMask provider
  private isBurning: boolean = false; // Flag to prevent contract reset during burns

  constructor() {
    this.currentChain = chainManager.getCurrentChain();
    this.setupChainChangeListener();
    this.initializeWeb3();
  }

  /**
   * Setup chain change listener
   */
  private setupChainChangeListener(): void {
    this.chainChangeUnsubscribe = chainManager.onChainChange((newChain) => {
      console.log(`🔄 Burn service: Chain changed to ${newChain.name}`);
      this.currentChain = newChain;
      // Only reset contracts if not currently burning
      if (!this.isBurning) {
        this.nftContract = null;
        console.log('🔄 Contract reset for chain change');
      } else {
        console.log('⚠️ Skipping contract reset - burn in progress');
      }
    });
  }

  /**
   * Cleanup listeners
   */
  public destroy(): void {
    if (this.chainChangeUnsubscribe) {
      this.chainChangeUnsubscribe();
    }
  }

  /**
   * Initialize Web3 with MetaMask provider - Multi-chain aware
   * Uses ChainManager's MetaMask detection to avoid Phantom
   */
  private async initializeWeb3(): Promise<void> {
    try {
      // ✅ Use ChainManager's MetaMask provider detection to avoid Phantom
      const provider = chainManager.getMetaMaskProvider();
      
      if (!provider) {
        throw new Error('MetaMask not available');
      }
      
      console.log('✅ Using MetaMask provider from ChainManager for NFT burning');
      
      this.web3 = new Web3(provider);
      this.selectedProvider = provider; // Store the selected provider
      
      // Get user account from the selected provider (not window.ethereum)
      const accounts = await provider.request({ method: 'eth_accounts' });
      this.userAccount = accounts[0];
      
      if (!this.userAccount) {
        throw new Error('No account connected');
      }
      
      console.log('👤 Connected account:', this.userAccount.toLowerCase());
      
      // Verify chain ID matches current chain
      const chainId = await this.web3.eth.getChainId();
      console.log('Connected to chain ID:', chainId);
      
      if (Number(chainId) !== this.currentChain.chainId) {
        throw new Error(`Wrong network. Expected ${this.currentChain.name} (${this.currentChain.chainId}), got ${chainId}`);
      }
      
      console.log(`✅ Web3 setup complete for burning on ${this.currentChain.name}`);
      
    } catch (error) {
      console.error('❌ Failed to initialize Web3:', error);
      throw error;
    }
  }


  /**
   * Initialize Web3 contracts for burning
   */
  private async initializeContracts(): Promise<void> {
    try {
      if (!this.web3) {
        await this.initializeWeb3();
      }

      if (!this.web3) {
        throw new Error('Web3 not initialized');
      }

      // Request account access if needed - use selected provider or ChainManager
      const provider = this.selectedProvider || chainManager.getMetaMaskProvider();
      if (provider) {
        await provider.request({ method: 'eth_requestAccounts' });
      } else {
        throw new Error('MetaMask provider not available');
      }
      
      // Get the connected account
      const accounts = await this.web3.eth.getAccounts();
      this.userAccount = accounts[0];
      
      if (!this.userAccount) {
        throw new Error('No accounts connected');
      }
      
      // Initialize NFT contract with current chain's contract address
      const nftContractAddress = this.currentChain.contracts?.nftContract;
      if (!nftContractAddress) {
        throw new Error(`NFT contract not configured for ${this.currentChain.name}`);
      }
      
      this.nftContract = new this.web3.eth.Contract(
        ERC721ABI as any,
        nftContractAddress
      );
      
      console.log('✅ Enhanced hybrid burn contracts initialized with wallet connection');
    } catch (error) {
      console.error('❌ Failed to initialize enhanced hybrid burn contracts:', error);
      throw error;
    }
  }

  /**
   * Check if on-chain burning is available
   */
  async isOnChainAvailable(): Promise<boolean> {
    try {
      if (!CONTRACT_ADDRESSES.NFT_CONTRACT) return false;
      await this.initializeContracts();
      return this.nftContract !== null;
    } catch (error) {
      console.error('On-chain burning not available:', error);
      return false;
    }
  }

  /**
   * Analyze NFT selection and group by status and rarity
   */
  private analyzeNFTSelection(nfts: NFTWithStatus[]): {
    burnGroups: BurnGroup[];
    burnStrategy: 'pure_offchain' | 'pure_onchain' | 'mixed';
    isValid: boolean;
    applicableRule?: BurnRule;
  } {
    console.log('🔍 Analyzing NFT selection for hybrid burn...');
    
    // Group NFTs by rarity
    const rarityGroups: Record<string, BurnGroup> = {};
    
    nfts.forEach(nft => {
      const rarity = nft.rarity.toLowerCase();
      if (!rarityGroups[rarity]) {
        rarityGroups[rarity] = {
          offchainNFTs: [],
          onchainNFTs: [],
          rarity,
          totalCount: 0
        };
      }
      
      if (nft.status === 'offchain') {
        rarityGroups[rarity].offchainNFTs.push(nft);
      } else {
        rarityGroups[rarity].onchainNFTs.push(nft);
      }
      rarityGroups[rarity].totalCount++;
    });

    const burnGroups = Object.values(rarityGroups);
    
    // Determine burn strategy
    let burnStrategy: 'pure_offchain' | 'pure_onchain' | 'mixed' = 'pure_offchain';
    const hasOffchain = nfts.some(nft => nft.status === 'offchain');
    const hasOnchain = nfts.some(nft => nft.status === 'onchain');
    
    if (hasOffchain && hasOnchain) {
      burnStrategy = 'mixed';
    } else if (hasOnchain && !hasOffchain) {
      burnStrategy = 'pure_onchain';
    }

    // Validate against burn rules
    const burnRules = optimizedCIDPoolBurnService.getBurnRules();
    let applicableRule: BurnRule | undefined;
    let isValid = false;

    // Check if any rarity group matches a burn rule
    for (const group of burnGroups) {
      const rule = burnRules.find(r => 
        r.minRarity.toLowerCase() === group.rarity && 
        r.requiredAmount === group.totalCount
      );
      
      if (rule) {
        applicableRule = rule;
        isValid = true;
        break;
      }
    }

    console.log('📊 Analysis result:', {
      burnStrategy,
      isValid,
      groupCount: burnGroups.length,
      applicableRule: applicableRule?.resultingNFT.rarity
    });

    return {
      burnGroups,
      burnStrategy,
      isValid,
      applicableRule
    };
  }

  /**
   * Execute smart hybrid burn based on NFT selection
   */
  async executeSmartHybridBurn(walletAddress: string, nfts: NFTWithStatus[]): Promise<BurnResult> {
    try {
      console.log(`🚀 Starting smart hybrid burn for ${nfts.length} NFTs`);

      // Analyze the selection
      const analysis = this.analyzeNFTSelection(nfts);
      
      if (!analysis.isValid || !analysis.applicableRule) {
        throw new Error('Invalid NFT combination for burning');
      }

      const { burnGroups, burnStrategy, applicableRule } = analysis;
      console.log(`🎯 Burn strategy: ${burnStrategy}`);

      let onchainBurnHashes: string[] = [];
      let resultNFT: NFTData;

      // Execute burn based on strategy
      switch (burnStrategy) {
        case 'pure_offchain':
          console.log('💾 Executing pure offchain burn...');
          return await this.executePureOffchainBurn(walletAddress, nfts.map(n => n.id));

        case 'pure_onchain':
          console.log('⛓️ Executing pure onchain burn with offchain result...');
          onchainBurnHashes = await this.burnOnchainNFTs(nfts.filter(n => n.status === 'onchain'));
          resultNFT = await this.getResultNFTFromOffchainPool(walletAddress, applicableRule.resultingNFT.rarity);
          break;

        case 'mixed':
          console.log('🔀 Executing mixed hybrid burn...');
          
          // Burn onchain NFTs on blockchain
          const onchainNFTs = nfts.filter(n => n.status === 'onchain');
          if (onchainNFTs.length > 0) {
            onchainBurnHashes = await this.burnOnchainNFTs(onchainNFTs);
          }

          // Burn offchain NFTs using offchain service
          const offchainNFTs = nfts.filter(n => n.status === 'offchain');
          if (offchainNFTs.length > 0) {
            await this.burnOffchainNFTsInDatabase(walletAddress, offchainNFTs.map(n => n.id));
          }

          // Get result NFT from offchain CID pool
          resultNFT = await this.getResultNFTFromOffchainPool(walletAddress, applicableRule.resultingNFT.rarity);
          break;

        default:
          throw new Error('Unknown burn strategy');
      }

      // Log the hybrid burn transaction
      let burnType: 'offchain' | 'onchain' | 'hybrid';
      if (burnStrategy === 'pure_onchain') {
        burnType = 'onchain';
      } else {
        burnType = 'hybrid';
      }

      const burnTransaction: BurnTransaction = {
        hash: onchainBurnHashes[0] || undefined,
        tokenIds: nfts.map(n => n.tokenId || n.id),
        resultRarity: applicableRule.resultingNFT.rarity,
        timestamp: Date.now(),
        burnType
      };

      await this.logHybridBurnTransaction(walletAddress, burnTransaction, nfts);

      console.log('✅ Smart hybrid burn completed successfully');
      return {
        success: true,
        resultNFT: resultNFT!
      };

    } catch (error) {
      console.error('❌ Smart hybrid burn failed:', error);
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Smart hybrid burn failed'
      };
    }
  }

  /**
   * Check if user has sufficient balance for gas fees
   */
  private async checkGasBalance(): Promise<{ hasBalance: boolean; balance: string; message: string }> {
    try {
      if (!this.web3 || !this.userAccount) {
        await this.initializeContracts();
      }

      if (!this.web3 || !this.userAccount) {
        return {
          hasBalance: false,
          balance: '0',
          message: 'Web3 not initialized'
        };
      }

      // Get user's native token balance
      const balanceWei = await this.web3.eth.getBalance(this.userAccount);
      const balanceEth = this.web3.utils.fromWei(balanceWei, 'ether');
      
      console.log(`💰 Current balance on ${this.currentChain.name}: ${balanceEth} ${this.currentChain.nativeCurrency.symbol}`);

      // Estimate gas for a single NFT burn (we'll use this as minimum required)
      const minRequiredBalance = '0.001'; // Minimum 0.001 native tokens for gas

      const hasBalance = parseFloat(balanceEth) >= parseFloat(minRequiredBalance);
      
      return {
        hasBalance,
        balance: balanceEth,
        message: hasBalance 
          ? `Balance: ${parseFloat(balanceEth).toFixed(4)} ${this.currentChain.nativeCurrency.symbol}`
          : `Insufficient balance for gas fees. You have ${parseFloat(balanceEth).toFixed(4)} ${this.currentChain.nativeCurrency.symbol}, but need at least ${minRequiredBalance} ${this.currentChain.nativeCurrency.symbol}`
      };
    } catch (error) {
      console.error('❌ Error checking gas balance:', error);
      // Throw the error so caller can handle RPC failures differently
      throw new Error(`Failed to check balance on ${this.currentChain.name}: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get chain from NFT (helper method)
   */
  private getChainFromNFT(nft: NFTWithStatus): string | null {
    // For onchain NFTs, use blockchain property
    if (nft.status === 'onchain' && nft.blockchain) {
      return nft.blockchain;
    }

    // For offchain NFTs, extract from attributes
    if (nft.status === 'offchain' && nft.attributes) {
      const chainAttr = nft.attributes.find(
        (attr: any) => attr.trait_type === 'Assigned Chain' || attr.trait_type === 'Chain'
      );
      const chainName = chainAttr?.value;

      if (chainName && typeof chainName === 'string') {
        // Map chain names to network identifiers
        const chainLower = chainName.toLowerCase();
        if (chainLower.includes('ethereum')) return 'sepolia';
        if (chainLower.includes('polygon')) return 'polygon-amoy';
        if (chainLower.includes('optimism')) return 'optimism-sepolia';
        if (chainLower.includes('bnb') || chainLower.includes('bsc')) return 'bsc-testnet';
        if (chainLower.includes('avalanche')) return 'avalanche-fuji';
        if (chainLower.includes('arbitrum')) return 'arbitrum-sepolia';
        if (chainLower.includes('base')) return 'base-sepolia';
      }
    }

    return null;
  }

  /**
   * Check balance on all chains before burning
   * Public method - can be called from hooks for pre-burn validation
   */
  public async checkBalanceOnAllChains(
    nftsByChain: Record<string, NFTWithStatus[]>
  ): Promise<{ success: boolean; insufficientChains: string[] }> {
    console.log(`💰 Checking balance on all chains before burning...`);
    console.log(`💰 Checking balance on all chains before burning...`);
   const chainCount = Object.keys(nftsByChain).length;
  toast.loading(`Checking gas balance on ${chainCount} chain(s)...`, { id: 'balance-check' });
    
    const insufficientChains: string[] = [];
    const currentChainId = chainManager.getCurrentChain().chainId;
    
    for (const chainNetwork of Object.keys(nftsByChain)) {
      const chainConfig = getChainByNetwork(chainNetwork);
      if (!chainConfig) {
        console.error(`❌ Chain config not found for ${chainNetwork}`);
        continue;
      }

      try {
        // Switch to chain if needed
        if (chainManager.getCurrentChain().network !== chainNetwork) {
          console.log(`🔄 Switching to ${chainConfig.name} to check balance...`);
          const chainKey = getChainKeyByNetwork(chainNetwork);
          if (!chainKey) {
            insufficientChains.push(chainConfig.name);
            continue;
          }
          await chainManager.switchChain(chainKey);
          
          // Reinitialize for new chain
          this.currentChain = chainManager.getCurrentChain();
          this.nftContract = null;
          await this.initializeContracts();
        }

        // Check balance
        try {
          const balanceCheck = await this.checkGasBalance();
          if (!balanceCheck.hasBalance) {
            console.log(`❌ Insufficient balance on ${chainConfig.name}: ${balanceCheck.message}`);
            insufficientChains.push(`${chainConfig.name} (need ${chainConfig.nativeCurrency.symbol})`);
          } else {
            console.log(`✅ Sufficient balance on ${chainConfig.name}: ${balanceCheck.balance} ${chainConfig.nativeCurrency.symbol}`);
          }
        } catch (balanceError) {
          // RPC error - skip this chain instead of blocking the burn
          console.warn(`⚠️ Could not verify balance on ${chainConfig.name} due to RPC error. Skipping balance check for this chain.`);
          console.warn(`   Error: ${balanceError instanceof Error ? balanceError.message : 'Unknown error'}`);
          // Don't add to insufficientChains - allow burn to proceed
        }
      } catch (error) {
        console.error(`❌ Error switching to ${chainNetwork}:`, error);
        // Network switch failed - this is a real error
        insufficientChains.push(`${chainConfig.name} (connection error)`);
      }
    }

    // Switch back to original chain if needed
    const finalChain = chainManager.getCurrentChain();
    if (finalChain.chainId !== currentChainId) {
      console.log(`🔄 Switching back to original chain...`);
      const chains = Object.values(SUPPORTED_CHAINS);
      const originalChain = chains.find(c => c.chainId === currentChainId);
      if (originalChain) {
        const chainKey = getChainKeyByNetwork(originalChain.network);
        if (chainKey) {
          await chainManager.switchChain(chainKey);
          this.currentChain = chainManager.getCurrentChain();
          this.nftContract = null;
          await this.initializeContracts();
        }
      }
    }
    
    // Show detailed balance check results
    if (insufficientChains.length === 0) {
      toast.success('✅ Balance verified on all chains!', { id: 'balance-check' });
    } else {
      // Format chain names with required currency
      const chainDetails = insufficientChains.map(chainNetwork => {
        const chainConfig = getChainByNetwork(chainNetwork);
        return chainConfig ? `${chainConfig.name} (need ${chainConfig.nativeCurrency.symbol})` : chainNetwork;
      }).join(', ');
      
      toast.error(
        `❌ Insufficient gas balance on: ${chainDetails}. Please add funds before burning.`,
        { 
          id: 'balance-check',
          duration: 8000 // Show for 8 seconds so user can read
        }
      );
    }

    return {
      success: insufficientChains.length === 0,
      insufficientChains
    };
  }

  /**
   * Burn onchain NFTs by transferring to burn address
   * Supports multi-chain burns by grouping NFTs by chain and burning sequentially
   */
  private async burnOnchainNFTs(onchainNFTs: NFTWithStatus[]): Promise<string[]> {
    console.log(`🔥 Burning ${onchainNFTs.length} onchain NFTs...`);
    
    // Group onchain NFTs by chain
    const nftsByChain: Record<string, NFTWithStatus[]> = {};
    onchainNFTs.forEach(nft => {
      const chain = this.getChainFromNFT(nft) || 'unknown';
      if (!nftsByChain[chain]) {
        nftsByChain[chain] = [];
      }
      nftsByChain[chain].push(nft);
    });

    const chains = Object.keys(nftsByChain);
    console.log(`🌐 NFTs distributed across ${chains.length} chain(s): ${chains.join(', ')}`);

    // 🚨 CHECK BALANCE ON ALL CHAINS FIRST
    const balanceCheck = await this.checkBalanceOnAllChains(nftsByChain);
    if (!balanceCheck.success) {
      const chainList = balanceCheck.insufficientChains.join(', ');
      throw new Error(`Insufficient gas balance on: ${chainList}. Please add funds before burning.`);
    }

    const allBurnHashes: string[] = [];

    // Burn NFTs on each chain sequentially
    for (const chainNetwork of chains) {
      const chainNFTs = nftsByChain[chainNetwork];
      console.log(`\n🔗 Processing ${chainNFTs.length} NFT(s) on ${chainNetwork}...`);

      // Switch to this chain if not already on it
      const chainConfig = getChainByNetwork(chainNetwork);
      if (!chainConfig) {
        console.error(`❌ Chain config not found for ${chainNetwork}, skipping...`);
        continue;
      }

      try {
        // Switch to the required chain
        if (chainManager.getCurrentChain().network !== chainNetwork) {
          console.log(`🔄 Switching to ${chainConfig.name}...`);
          
          // Get the chain key for switching
          const chainKey = getChainKeyByNetwork(chainNetwork);
          if (!chainKey) {
            throw new Error(`Chain key not found for ${chainNetwork}`);
          }
          
          await chainManager.switchChain(chainKey);
          
          // Reinitialize contracts for new chain
          this.currentChain = chainManager.getCurrentChain();
          this.nftContract = null;
          await this.initializeContracts();
        }

        // Balance already checked upfront, proceed with burn
        console.log(`✅ Balance verified, proceeding with burn on ${chainConfig.name}`);

        // Burn NFTs on this chain
        const burnHashes = await this.burnNFTsOnCurrentChain(chainNFTs);
        allBurnHashes.push(...burnHashes);

        console.log(`✅ Successfully burned ${chainNFTs.length} NFT(s) on ${chainConfig.name}`);
      } catch (error) {
        console.error(`❌ Failed to burn NFTs on ${chainNetwork}:`, error);
        throw error;
      }
    }

    return allBurnHashes;
  }

  /**
   * Burn NFTs on the current chain (helper method for multi-chain burns)
   */
  private async burnNFTsOnCurrentChain(nfts: NFTWithStatus[]): Promise<string[]> {
    const burnHashes: string[] = [];
    
    // Set burning flag to prevent contract reset
    this.isBurning = true;
    
    try {
      // Ensure contracts are initialized before burning
      if (!this.nftContract || !this.web3 || !this.userAccount) {
        console.log('⚠️ Contracts not initialized, initializing now...');
        await this.initializeContracts();
        
        if (!this.nftContract) {
          throw new Error('Failed to initialize NFT contract for burning');
        }
      }
    
    for (const nft of nfts) {
      try {
        const tokenId = parseInt(nft.tokenId || nft.id);
        
        // Check if NFT is staked - staked NFTs cannot be burned
        // For onchain NFTs, this should already be checked by blockchain status
        if (nft.id.includes('staked_') || nft.stakingStatus === 'staked' || nft.isStaked === true) {
          console.error(`❌ Cannot burn staked NFT ${tokenId} - must unstake first`);
          throw new Error(`NFT ${tokenId} is currently staked and cannot be burned. Please unstake it first.`);
        }
        
        console.log(`🔗 Burning onchain NFT ${tokenId}...`);
        
        // Estimate gas for the transfer
        const gasLimit = await this.nftContract.methods
          .transferFrom(this.userAccount, this.BURN_ADDRESS, tokenId)
          .estimateGas({ from: this.userAccount });
        
        // Get current gas price
        const gasPrice = await this.web3.eth.getGasPrice();
        
        // Execute the transfer to burn address
        const result = await this.nftContract.methods
          .transferFrom(this.userAccount, this.BURN_ADDRESS, tokenId)
          .send({
            from: this.userAccount,
            gas: Math.floor(Number(gasLimit) * 1.2), // 20% buffer
            gasPrice: gasPrice
          });
        
        burnHashes.push(result.transactionHash);
        console.log(`✅ Onchain NFT ${tokenId} burned: ${result.transactionHash}`);
      } catch (error) {
        console.error(`❌ Failed to burn onchain NFT ${nft.id}:`, error);
        throw error;
      }
    }

    return burnHashes;
    } finally {
      // Clear burning flag
      this.isBurning = false;
      console.log('✅ Burn operation completed, contract can be reset on chain changes');
    }
  }

  /**
   * Burn offchain NFTs by removing from database
   */
  private async burnOffchainNFTsInDatabase(walletAddress: string, nftIds: string[]): Promise<void> {
    console.log(`🗑️ Burning ${nftIds.length} offchain NFTs in database...`);
    
    try {
      const client = getWalletSupabaseClient(walletAddress);

      const { error } = await client
        .from('nft_cid_distribution_log')
        .delete()
        .eq('wallet_address', walletAddress.toLowerCase())
        .in('nft_id', nftIds);

      if (error) {
        throw new Error(`Failed to burn offchain NFTs: ${error.message}`);
      }

      console.log(`✅ Burned ${nftIds.length} offchain NFTs from database`);
    } catch (error) {
      console.error('❌ Error burning offchain NFTs:', error);
      throw error;
    }
  }

  /**
   * Get result NFT from offchain CID pool and add to user's collection
   */
  private async getResultNFTFromOffchainPool(walletAddress: string, rarity: string): Promise<NFTData> {
    console.log(`🎁 Getting result NFT from offchain CID pool: ${rarity}`);
    
    try {
      const { getWalletSupabaseClient } = await import('../lib/supabaseClientManager');
      const client = getWalletSupabaseClient(walletAddress);

      // Get available NFT from CID pool
      const { data: cidPoolNFT, error: poolError } = await client
        .from('nft_cid_pools')
        .select('*')
        .eq('rarity', rarity.toLowerCase())
        .eq('is_distributed', false)
        .limit(1)
        .single();

      if (poolError || !cidPoolNFT) {
        throw new Error(`No available ${rarity} NFT found in CID pool`);
      }

      // Create result NFT
      const resultNFT: NFTData = {
        id: uuidv4(),
        name: `NEFTIT ${rarity.charAt(0).toUpperCase() + rarity.slice(1)} NFT`,
        description: '',
        image: cidPoolNFT.image_url || getIPFSUrl(cidPoolNFT.cid),
        rarity: rarity,
        wallet_address: walletAddress,
        ipfs_hash: cidPoolNFT.cid,
        pinata_hash: cidPoolNFT.cid,
        metadata_uri: getIPFSUrl(cidPoolNFT.metadata_cid),
        attributes: [
          { trait_type: 'Rarity', value: rarity.charAt(0).toUpperCase() + rarity.slice(1) },
          { trait_type: 'Platform', value: 'NEFTIT' },
          { trait_type: 'Source', value: 'Hybrid Burn Upgrade' }
        ],
        created_at: new Date().toISOString()
      };

      // Ensure user exists in user_nft_collections table first
      const { error: syncError } = await client.rpc('sync_user_nft_collection', {
        p_wallet_address: walletAddress.toLowerCase()
      });

      if (syncError) {
        console.warn('⚠️ Warning syncing user collection (continuing anyway):', syncError);
      }

      // Add to user's collection
      const { error: insertError } = await client
        .from('nft_cid_distribution_log')
        .insert({
          nft_id: resultNFT.id,
          wallet_address: walletAddress.toLowerCase(),
          rarity: resultNFT.rarity,
          cid: resultNFT.ipfs_hash,
          distributed_at: new Date().toISOString()
        });

      if (insertError) {
        throw new Error(`Failed to add result NFT: ${insertError.message}`);
      }

      // Mark CID pool NFT as distributed
      const { error: updateError } = await client
        .from('nft_cid_pools')
        .update({
          is_distributed: true,
          distributed_at: new Date().toISOString(),
          distributed_to_wallet: walletAddress.toLowerCase()
        })
        .eq('id', cidPoolNFT.id);

      if (updateError) {
        console.error('❌ Error marking CID pool NFT as distributed:', updateError);
      }

      console.log(`✅ Result NFT created and added to collection: ${resultNFT.id}`);
      return resultNFT;

    } catch (error) {
      console.error('❌ Error getting result NFT from offchain pool:', error);
      throw error;
    }
  }

  /**
   * Execute pure offchain burn (delegate to existing service)
   */
  private async executePureOffchainBurn(walletAddress: string, nftIds: string[]): Promise<BurnResult> {
    console.log('💾 Delegating to pure offchain burn service...');
    return await optimizedCIDPoolBurnService.burnNFTsOffChain(walletAddress, nftIds);
  }

  /**
   * Log hybrid burn transaction
   */
  private async logHybridBurnTransaction(
    walletAddress: string, 
    transaction: BurnTransaction, 
    burnedNFTs: NFTWithStatus[]
  ): Promise<void> {
    try {
      const { getWalletSupabaseClient } = await import('../lib/supabaseClientManager');
      const client = getWalletSupabaseClient(walletAddress);
      
      const { error } = await client
        .from('burn_transactions')
        .insert({
          wallet_address: walletAddress.toLowerCase(),
          burned_nft_ids: burnedNFTs.map(nft => nft.id),
          result_rarity: transaction.resultRarity,
          burn_type: transaction.burnType,
          transaction_hash: transaction.hash || null,
          contract_address: transaction.burnType !== 'offchain' ? CONTRACT_ADDRESSES.NFT_CONTRACT : null,
          gas_used: transaction.gasUsed || null,
          network: transaction.burnType !== 'offchain' ? this.currentChain.network : null,
          created_at: new Date(transaction.timestamp).toISOString(),
          metadata: {
            burn_method: 'enhanced_hybrid',
            onchain_nfts: burnedNFTs.filter(n => n.status === 'onchain').length,
            offchain_nfts: burnedNFTs.filter(n => n.status === 'offchain').length,
            burn_strategy: transaction.burnType,
            burn_address: transaction.burnType !== 'offchain' ? this.BURN_ADDRESS : null
          }
        });

      if (error) {
        console.error('❌ Error logging hybrid burn transaction:', error);
      } else {
        console.log('✅ Hybrid burn transaction logged successfully');
      }
    } catch (error) {
      console.error('❌ Error logging hybrid burn transaction:', error);
    }
  }

  /**
   * Get burn rules (delegate to existing service)
   */
  getBurnRules(): BurnRule[] {
    return optimizedCIDPoolBurnService.getBurnRules();
  }

  /**
   * Get configuration for debugging
   */
  getConfiguration(): { isConfigured: boolean; nftContractAddress: string; network: string } {
    return {
      nftContractAddress: CONTRACT_ADDRESSES.NFT_CONTRACT,
      network: this.currentChain.network,
      isConfigured: !!(CONTRACT_ADDRESSES.NFT_CONTRACT)
    };
  }
}

export const enhancedHybridBurnService = new EnhancedHybridBurnService();
export default enhancedHybridBurnService;
