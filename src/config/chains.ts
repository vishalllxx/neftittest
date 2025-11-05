/**
 * Multi-Chain Configuration for EVM Testnets
 * Comprehensive support for all major EVM chain testnets
 */

export interface ChainConfig {
  chainId: number;
  chainIdHex: string;
  name: string;
  network: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  rpcUrls: string[];
  blockExplorerUrls: string[];
  iconUrl?: string;
  isTestnet: boolean;
  contracts?: {
    nftContract?: string;
    stakingContract?: string;
  };
}

export const SUPPORTED_CHAINS: Record<string, ChainConfig> = {
  // Polygon Amoy Testnet
  POLYGON_AMOY: {
    chainId: 80002,
    chainIdHex: '0x13882',
    name: 'Polygon Amoy Testnet',
    network: 'polygon-amoy',
    nativeCurrency: {
      name: 'MATIC',
      symbol: 'MATIC',
      decimals: 18,
    },
    rpcUrls: [
      'https://rpc-amoy.polygon.technology/',
      'https://polygon-amoy.drpc.org',
      'https://polygon-amoy-bor-rpc.publicnode.com',
      'https://rpc.ankr.com/polygon_amoy',
      // Add your own Alchemy key: `https://polygon-amoy.g.alchemy.com/v2/${process.env.VITE_ALCHEMY_API_KEY}`,
    ],
    blockExplorerUrls: ['https://amoy.polygonscan.com/'],
    iconUrl: '/chain-logos/PolygonAmoyTestnet.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_POLYGON_NFT_CONTRACT || '0x5Bb23220cC12585264fCd144C448eF222c8572A2',
      stakingContract: process.env.VITE_POLYGON_STAKING_CONTRACT || '0x1F2Dbf590b1c4C96c1ddb4FF55002Dbb33DA294e',
    },
  },

  // Ethereum Sepolia Testnet
  SEPOLIA: {
    chainId: 11155111,
    chainIdHex: '0xaa36a7',
    name: 'Ethereum Sepolia',
    network: 'sepolia',
    nativeCurrency: {
      name: 'Sepolia Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: [
      'https://ethereum-sepolia-rpc.publicnode.com',
      'https://rpc.ankr.com/eth_sepolia',
      'https://1rpc.io/sepolia',
      // 'https://rpc.sepolia.org', // CORS-blocked in browsers, moved to end as fallback
      // Add your own Alchemy key: `https://eth-sepolia.g.alchemy.com/v2/${process.env.VITE_ALCHEMY_API_KEY}`,
    ],
    blockExplorerUrls: ['https://sepolia.etherscan.io/'],
    iconUrl: '/chain-logos/EthereumLogo.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_SEPOLIA_NFT_CONTRACT || '0xedE55c384D620dD9a06d39fA632b2B55f29Bd387',
      stakingContract: process.env.VITE_SEPOLIA_STAKING_CONTRACT || '0x637B5CbfBFd074Fe468e2B976b780862448F984C',
    },
  },

  // BSC Testnet
  BSC_TESTNET: {
    chainId: 97,
    chainIdHex: '0x61',
    name: 'BNB Smart Chain Testnet',
    network: 'bsc-testnet',
    nativeCurrency: {
      name: 'Test BNB',
      symbol: 'tBNB',
      decimals: 18,
    },
    rpcUrls: [
      'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
      'https://data-seed-prebsc-2-s1.bnbchain.org:8545',
      'https://bsc-testnet.publicnode.com',
      'https://bsc-testnet-rpc.publicnode.com',
    ],
    blockExplorerUrls: ['https://testnet.bscscan.com/'],
    iconUrl: '/chain-logos/BNBSmartChainTestnet.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_BSC_NFT_CONTRACT || '0xfaAA35A41f070B7408740Fefff0635fD5B66398b',
      stakingContract: process.env.VITE_BSC_STAKING_CONTRACT || '0x1FAe00647ff1931Ab9d234E685EAf5211bed12b7',
    },
  },

  // Avalanche Fuji Testnet
  AVALANCHE_FUJI: {
    chainId: 43113,
    chainIdHex: '0xa869',
    name: 'Avalanche Fuji Testnet',
    network: 'avalanche-fuji',
    nativeCurrency: {
      name: 'AVAX',
      symbol: 'AVAX',
      decimals: 18,
    },
    rpcUrls: [
      'https://api.avax-test.network/ext/bc/C/rpc',
      'https://avalanche-fuji-c-chain-rpc.publicnode.com',
      'https://rpc.ankr.com/avalanche_fuji',
      'https://ava-testnet.public.blastapi.io/ext/bc/C/rpc',
    ],
    blockExplorerUrls: ['https://testnet.snowtrace.io/'],
    iconUrl: '/chain-logos/AvalancheFujiTestnet.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_AVALANCHE_NFT_CONTRACT || '0x7a85EE8944EC9d15528c7517D1FD2A173f552F08',
      stakingContract: process.env.VITE_AVALANCHE_STAKING_CONTRACT || '0x95F2B1d375532690a78f152E4c90F4a6196fB8Df',
    },
  },

  // Arbitrum Sepolia Testnet
  ARBITRUM_SEPOLIA: {
    chainId: 421614,
    chainIdHex: '0x66eee',
    name: 'Arbitrum Sepolia',
    network: 'arbitrum-sepolia',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: [
      'https://sepolia-rollup.arbitrum.io/rpc',
      'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
      'https://arbitrum-sepolia-rpc.publicnode.com',
    ],
    blockExplorerUrls: ['https://sepolia.arbiscan.io/'],
    iconUrl: '/chain-logos/ArbitrumSepolia.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_ARBITRUM_NFT_CONTRACT || '0x71EC87B1aFBe18255e8c415c3d84c9369719de21',
      stakingContract: process.env.VITE_ARBITRUM_STAKING_CONTRACT ||'0x5B17525Db3B6811F36a0e301d0Ff286b44b51147',
    },
  },

  // Optimism Sepolia Testnet
  OPTIMISM_SEPOLIA: {
    chainId: 11155420,
    chainIdHex: '0xaa37dc',
    name: 'Optimism Sepolia',
    network: 'optimism-sepolia',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: [
      'https://sepolia.optimism.io',
      'https://optimism-sepolia.blockpi.network/v1/rpc/public',
      'https://optimism-sepolia-rpc.publicnode.com',
    ],
    blockExplorerUrls: ['https://sepolia-optimism.etherscan.io/'],
    iconUrl: '/chain-logos/OptimismSepolia.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_OPTIMISM_NFT_CONTRACT || '0x68C3734b65e3b2f7858123ccb5Bfc5fd7cC1D733',
      stakingContract: process.env.VITE_OPTIMISM_STAKING_CONTRACT || '0x37Fdb126989C1c355b93f0155FEe0CbD0e892AF8',
    },
  },

  // Base Sepolia Testnet
  BASE_SEPOLIA: {
    chainId: 84532,
    chainIdHex: '0x14a34',
    name: 'Base Sepolia',
    network: 'base-sepolia',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: [
      'https://sepolia.base.org',
      'https://base-sepolia.blockpi.network/v1/rpc/public',
      'https://base-sepolia-rpc.publicnode.com',
    ],
    blockExplorerUrls: ['https://sepolia.basescan.org/'],
    iconUrl: '/chain-logos/BaseSepolia.png',
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_BASE_NFT_CONTRACT || '0x10ca82E3F31459f7301BDE2ca8Cf93CCA4113705',
      stakingContract: process.env.VITE_BASE_STAKING_CONTRACT || '0xB250CD56aDB08cd30aBC275b9E20978A92bC4dd1',
    },
  },
};

// Default chain (Polygon Amoy)
export const DEFAULT_CHAIN = SUPPORTED_CHAINS.POLYGON_AMOY;

// Get all available chains as array
export const AVAILABLE_CHAINS = Object.values(SUPPORTED_CHAINS);

// Helper to get chain by chainId
export function getChainById(chainId: number): ChainConfig | undefined {
  return AVAILABLE_CHAINS.find(chain => chain.chainId === chainId);
}

// Helper to get chain by network name
export function getChainByNetwork(network: string): ChainConfig | undefined {
  return AVAILABLE_CHAINS.find(chain => chain.network === network);
}

// Helper to get chain key by network name
export function getChainKeyByNetwork(network: string): string | undefined {
  const entry = Object.entries(SUPPORTED_CHAINS).find(
    ([_, config]) => config.network === network
  );
  return entry?.[0];
}

// Helper to check if chain is supported
export function isChainSupported(chainId: number): boolean {
  return AVAILABLE_CHAINS.some(chain => chain.chainId === chainId);
}

// Helper to get contract addresses for current chain
export function getContractAddresses(chainId: number) {
  const chain = getChainById(chainId);
  return chain?.contracts || { nftContract: '', stakingContract: '' };
}
