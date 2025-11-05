/**
 * Chain Manager Service
 * Handles dynamic chain switching, persistence, and wallet network management
 */

import { ChainConfig, SUPPORTED_CHAINS, DEFAULT_CHAIN, getChainById, isChainSupported } from '../config/chains';

export type ChainChangeCallback = (chain: ChainConfig) => void;

class ChainManagerService {
  private currentChain: ChainConfig;
  private callbacks: Set<ChainChangeCallback> = new Set();
  private readonly STORAGE_KEY = 'neftit_selected_chain';
  private metamaskProvider: any = null;

  constructor() {
    // Load persisted chain or use default
    this.currentChain = this.loadPersistedChain() || DEFAULT_CHAIN;
    this.detectMetaMaskProvider();
    this.setupMetaMaskListeners();
  }

  /**
   * Detect the actual MetaMask provider (not Phantom)
   */
  private detectMetaMaskProvider(): void {
    if (!window.ethereum) {
      console.warn('No ethereum provider detected');
      return;
    }

    // Check if multiple providers exist (MetaMask + Phantom both installed)
    if (window.ethereum.providers && Array.isArray(window.ethereum.providers)) {
      console.log('🔍 Multiple wallet providers detected, searching for MetaMask...');
      // Find the actual MetaMask provider (not Phantom)
      const metamask = window.ethereum.providers.find(
        (p: any) => p.isMetaMask && !p.isPhantom
      );
      if (metamask) {
        this.metamaskProvider = metamask;
        console.log('✅ Found MetaMask provider');
      } else {
        console.warn('⚠️ MetaMask not found in providers array');
        this.metamaskProvider = window.ethereum;
      }
    } else if (window.ethereum.isMetaMask && !window.ethereum.isPhantom) {
      // Only MetaMask is installed
      this.metamaskProvider = window.ethereum;
      console.log('✅ MetaMask is the primary provider');
    } else if (window.ethereum.isPhantom) {
      // Phantom is masquerading as primary provider
      console.warn('⚠️ Phantom detected as primary provider, MetaMask required for EVM chains');
      this.metamaskProvider = window.ethereum; // Fallback, but will likely fail
    } else {
      // Unknown provider
      this.metamaskProvider = window.ethereum;
    }
  }

  /**
   * Get current active chain
   */
  getCurrentChain(): ChainConfig {
    return this.currentChain;
  }

  /**
   * Get current chain ID
   */
  getCurrentChainId(): number {
    return this.currentChain.chainId;
  }

  /**
   * Switch to a different chain
   */
  async switchChain(chainKey: string): Promise<boolean> {
    const chain = SUPPORTED_CHAINS[chainKey];
    if (!chain) {
      console.error(`Chain ${chainKey} not found`);
      return false;
    }

    try {
      // Re-detect MetaMask provider in case it changed
      this.detectMetaMaskProvider();

      // If MetaMask is available, request chain switch
      if (this.metamaskProvider) {
        await this.switchMetaMaskChain(chain);
      } else {
        console.warn('⚠️ MetaMask not available for chain switch');
      }

      // Update current chain
      this.setCurrentChain(chain);
      return true;
    } catch (error) {
      console.error('Failed to switch chain:', error);
      throw error;
    }
  }

  /**
   * Switch MetaMask to specified chain
   * Uses the detected MetaMask provider to avoid triggering Phantom
   */
  private async switchMetaMaskChain(chain: ChainConfig): Promise<void> {
    if (!this.metamaskProvider) {
      throw new Error('MetaMask provider not detected');
    }

    console.log(`🔄 Switching to ${chain.name} (${chain.chainIdHex}) using MetaMask provider`);

    try {
      // Try to switch to the chain using the actual MetaMask provider
      await this.metamaskProvider.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: chain.chainIdHex }],
      });
      console.log(`✅ Successfully switched to ${chain.name}`);
    } catch (switchError: any) {
      // Chain not added to MetaMask, add it
      if (switchError.code === 4902) {
        console.log(`➕ Adding ${chain.name} to MetaMask...`);
        try {
          await this.metamaskProvider.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: chain.chainIdHex,
              chainName: chain.name,
              nativeCurrency: chain.nativeCurrency,
              rpcUrls: [chain.rpcUrls[0]],
              blockExplorerUrls: chain.blockExplorerUrls,
            }],
          });
          console.log(`✅ Successfully added and switched to ${chain.name}`);
        } catch (addError) {
          console.error('Failed to add chain to MetaMask:', addError);
          throw addError;
        }
      } else {
        throw switchError;
      }
    }
  }

  /**
   * Set current chain and notify listeners
   */
  private setCurrentChain(chain: ChainConfig): void {
    this.currentChain = chain;
    this.persistChain(chain);
    this.notifyChainChange(chain);
  }

  /**
   * Register callback for chain changes
   */
  onChainChange(callback: ChainChangeCallback): () => void {
    this.callbacks.add(callback);
    // Return unsubscribe function
    return () => this.callbacks.delete(callback);
  }

  /**
   * Notify all listeners of chain change
   * Uses setTimeout to make callbacks non-blocking for faster UI response
   */
  private notifyChainChange(chain: ChainConfig): void {
    this.callbacks.forEach(callback => {
      // Execute callbacks asynchronously to avoid blocking MetaMask switch
      setTimeout(() => {
        try {
          callback(chain);
        } catch (error) {
          console.error('Chain change callback error:', error);
        }
      }, 0);
    });
  }

  /**
   * Setup MetaMask event listeners
   * Uses the detected MetaMask provider to avoid Phantom events
   */
  private setupMetaMaskListeners(): void {
    // Use detected MetaMask provider, fallback to window.ethereum
    const provider = this.metamaskProvider || window.ethereum;
    
    if (provider) {
      provider.on('chainChanged', (chainIdHex: string) => {
        const chainId = parseInt(chainIdHex, 16);
        console.log('MetaMask chain changed to:', chainId);

        const chain = getChainById(chainId);
        if (chain) {
          this.setCurrentChain(chain);
        } else {
          console.warn('Switched to unsupported chain:', chainId);
          // Optionally switch back to default chain
          this.switchChain('POLYGON_AMOY').catch(console.error);
        }
      });

      provider.on('accountsChanged', (accounts: string[]) => {
        console.log('MetaMask accounts changed:', accounts);
        // Optionally reload or re-initialize services
      });
    }
  }

  /**
   * Detect and sync with current MetaMask chain
   * Uses the detected MetaMask provider
   */
  async syncWithMetaMask(): Promise<ChainConfig> {
    // Re-detect MetaMask provider
    this.detectMetaMaskProvider();

    if (!this.metamaskProvider) {
      console.warn('MetaMask not available');
      return this.currentChain;
    }

    try {
      const chainIdHex = await this.metamaskProvider.request({ method: 'eth_chainId' });
      const chainId = parseInt(chainIdHex as string, 16);
      
      const chain = getChainById(chainId);
      if (chain) {
        this.setCurrentChain(chain);
        return chain;
      } else {
        console.warn('MetaMask is on unsupported chain:', chainId);
        // Switch to default chain
        await this.switchChain('POLYGON_AMOY');
        return this.currentChain;
      }
    } catch (error) {
      console.error('Failed to sync with MetaMask:', error);
      return this.currentChain;
    }
  }

  /**
   * Persist selected chain to localStorage
   */
  private persistChain(chain: ChainConfig): void {
    try {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify({
        chainId: chain.chainId,
        network: chain.network,
      }));
    } catch (error) {
      console.warn('Failed to persist chain:', error);
    }
  }

  /**
   * Load persisted chain from localStorage
   */
  private loadPersistedChain(): ChainConfig | null {
    try {
      const stored = localStorage.getItem(this.STORAGE_KEY);
      if (!stored) return null;

      const { chainId } = JSON.parse(stored);
      return getChainById(chainId) || null;
    } catch (error) {
      console.warn('Failed to load persisted chain:', error);
      return null;
    }
  }

  /**
   * Check if wallet is on correct network
   * Uses the detected MetaMask provider
   */
  async isOnCorrectNetwork(): Promise<boolean> {
    // Use detected MetaMask provider or fallback
    const provider = this.metamaskProvider || window.ethereum;
    if (!provider) return false;

    try {
      const chainIdHex = await provider.request({ method: 'eth_chainId' });
      const chainId = parseInt(chainIdHex as string, 16);
      return chainId === this.currentChain.chainId;
    } catch (error) {
      console.error('Failed to check network:', error);
      return false;
    }
  }

  /**
   * Get RPC URLs for current chain
   */
  getRpcUrls(): string[] {
    return this.currentChain.rpcUrls;
  }

  /**
   * Get contract addresses for current chain
   */
  getContractAddresses() {
    return this.currentChain.contracts || { nftContract: '', stakingContract: '' };
  }

  /**
   * Get block explorer URL for current chain
   */
  getBlockExplorerUrl(): string {
    return this.currentChain.blockExplorerUrls[0];
  }

  /**
   * Get transaction URL for current chain
   */
  getTxUrl(txHash: string): string {
    return `${this.getBlockExplorerUrl()}tx/${txHash}`;
  }

  /**
   * Get address URL for current chain
   */
  getAddressUrl(address: string): string {
    return `${this.getBlockExplorerUrl()}address/${address}`;
  }

  /**
   * Get all available chains
   */
  getAvailableChains(): ChainConfig[] {
    return Object.values(SUPPORTED_CHAINS);
  }

  /**
   * Check if contracts are configured for current chain
   */
  hasContractsConfigured(): boolean {
    const contracts = this.getContractAddresses();
    return !!(contracts.nftContract && contracts.stakingContract);
  }

  /**
   * Get the detected MetaMask provider (not Phantom)
   * Useful for other services that need to interact with MetaMask
   */
  getMetaMaskProvider(): any {
    if (!this.metamaskProvider) {
      this.detectMetaMaskProvider();
    }
    return this.metamaskProvider;
  }
}

// Export singleton instance
export const chainManager = new ChainManagerService();
