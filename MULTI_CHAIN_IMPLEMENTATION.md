# Multi-Chain EVM Testnet Implementation

## Overview

The application now supports **10 major EVM testnets** with seamless chain switching, automatic network detection, and persistent chain selection.

## Supported Networks

| Network | Chain ID | Native Currency | Status |
|---------|----------|----------------|---------|
| **Polygon Amoy** | 80002 | MATIC | ✅ Configured |
| **Ethereum Sepolia** | 11155111 | ETH | 🔧 Contracts needed |
| **BSC Testnet** | 97 | tBNB | 🔧 Contracts needed |
| **Avalanche Fuji** | 43113 | AVAX | 🔧 Contracts needed |
| **Arbitrum Sepolia** | 421614 | ETH | 🔧 Contracts needed |
| **Optimism Sepolia** | 11155420 | ETH | 🔧 Contracts needed |
| **Base Sepolia** | 84532 | ETH | 🔧 Contracts needed |
| **Fantom Testnet** | 4002 | FTM | 🔧 Contracts needed |
| **Scroll Sepolia** | 534351 | ETH | 🔧 Contracts needed |
| **Linea Sepolia** | 59141 | ETH | 🔧 Contracts needed |

## Architecture

### Core Components

#### 1. **Chain Configuration** (`src/config/chains.ts`)
Defines all supported chains with:
- Chain ID and hex format
- RPC endpoints (multiple fallbacks)
- Block explorers
- Native currency details
- Contract addresses (per chain)

```typescript
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
  contracts?: {
    nftContract?: string;
    stakingContract?: string;
  };
}
```

#### 2. **Chain Manager Service** (`src/services/ChainManagerService.ts`)
Centralized chain management:
- **Dynamic chain switching**
- **MetaMask integration**
- **Chain persistence** (localStorage)
- **Event-driven updates**
- **Automatic network sync**

Key Methods:
```typescript
chainManager.switchChain(chainKey: string)
chainManager.getCurrentChain()
chainManager.onChainChange(callback)
chainManager.getContractAddresses()
chainManager.getTxUrl(txHash)
```

#### 3. **Updated Services**
All blockchain services now support multi-chain:

- **Web3MetaMaskNFTService** - NFT minting/claiming
- **EnhancedHybridBurnService** - NFT burning
- **ImprovedOnchainStakingService** - NFT/Token staking

Features:
- ✅ Auto-detect current chain
- ✅ Listen for chain changes
- ✅ Reset state on chain switch
- ✅ Use chain-specific contracts
- ✅ Chain-specific RPC endpoints

#### 4. **UI Components**

**ChainSelector Component** (`src/components/ChainSelector.tsx`)
```tsx
import { ChainSelector } from '@/components/ChainSelector';

<ChainSelector 
  showFullName={true}
  onChainChange={(chain) => console.log('Switched to:', chain.name)}
/>
```

**useChain Hook** (`src/hooks/useChain.ts`)
```tsx
import { useChain } from '@/hooks/useChain';

function MyComponent() {
  const { 
    currentChain, 
    isCorrectNetwork, 
    switchChain,
    hasContracts 
  } = useChain();
  
  return (
    <div>
      Current: {currentChain.name}
      {!isCorrectNetwork && <Alert>Wrong network!</Alert>}
    </div>
  );
}
```

## Configuration

### Environment Variables

Add contract addresses for each chain you want to support:

```env
# Polygon Amoy (default - already configured)
VITE_POLYGON_NFT_CONTRACT=0x5Bb23220cC12585264fCd144C448eF222c8572A2
VITE_POLYGON_STAKING_CONTRACT=0x1F2Dbf590b1c4C96c1ddb4FF55002Dbb33DA294e

# Ethereum Sepolia
VITE_SEPOLIA_NFT_CONTRACT=0x...
VITE_SEPOLIA_STAKING_CONTRACT=0x...

# BSC Testnet
VITE_BSC_NFT_CONTRACT=0x...
VITE_BSC_STAKING_CONTRACT=0x...

# Avalanche Fuji
VITE_AVALANCHE_NFT_CONTRACT=0x...
VITE_AVALANCHE_STAKING_CONTRACT=0x...

# And so on for other chains...
```

### Adding a New Chain

1. **Add to `chains.ts`:**
```typescript
export const SUPPORTED_CHAINS = {
  // ... existing chains
  
  MY_CHAIN: {
    chainId: 123456,
    chainIdHex: '0x1e240',
    name: 'My Custom Testnet',
    network: 'my-testnet',
    nativeCurrency: {
      name: 'Test Token',
      symbol: 'TEST',
      decimals: 18,
    },
    rpcUrls: [
      'https://rpc.mytestnet.com',
      'https://rpc2.mytestnet.com',
    ],
    blockExplorerUrls: ['https://explorer.mytestnet.com/'],
    isTestnet: true,
    contracts: {
      nftContract: process.env.VITE_MYCHAIN_NFT_CONTRACT,
      stakingContract: process.env.VITE_MYCHAIN_STAKING_CONTRACT,
    },
  },
};
```

2. **Add environment variables:**
```env
VITE_MYCHAIN_NFT_CONTRACT=0x...
VITE_MYCHAIN_STAKING_CONTRACT=0x...
```

3. **Deploy contracts to the new chain** (see Deployment section)

## Usage Examples

### Basic Chain Switching

```typescript
import { chainManager } from '@/services/ChainManagerService';

// Switch to Sepolia
await chainManager.switchChain('SEPOLIA');

// Get current chain info
const chain = chainManager.getCurrentChain();
console.log(chain.name, chain.chainId);

// Get contract addresses for current chain
const contracts = chainManager.getContractAddresses();
console.log('NFT:', contracts.nftContract);
console.log('Staking:', contracts.stakingContract);
```

### React Component with Chain Selector

```tsx
import React from 'react';
import { ChainSelector } from '@/components/ChainSelector';
import { useChain } from '@/hooks/useChain';

function MyDApp() {
  const { currentChain, isCorrectNetwork, hasContracts } = useChain();
  
  return (
    <div>
      <header>
        <ChainSelector showFullName={true} />
      </header>
      
      {!isCorrectNetwork && (
        <Alert type="warning">
          Please switch to {currentChain.name} in MetaMask
        </Alert>
      )}
      
      {!hasContracts && (
        <Alert type="info">
          Contracts not deployed on {currentChain.name} yet
        </Alert>
      )}
      
      <main>
        {/* Your DApp content */}
      </main>
    </div>
  );
}
```

### Listening to Chain Changes

```typescript
import { chainManager } from '@/services/ChainManagerService';

// Subscribe to chain changes
const unsubscribe = chainManager.onChainChange((newChain) => {
  console.log('Switched to:', newChain.name);
  // Update your UI, reload data, etc.
});

// Later, unsubscribe
unsubscribe();
```

### Getting Transaction/Address URLs

```typescript
import { chainManager } from '@/services/ChainManagerService';

// Get block explorer URLs
const txUrl = chainManager.getTxUrl('0x123...');
const addressUrl = chainManager.getAddressUrl('0xabc...');

// Open in new tab
window.open(txUrl, '_blank');
```

## Backward Compatibility

Old code using `CONTRACT_ADDRESSES` and `NETWORK_CONFIG` still works:

```typescript
// Old code (still works)
import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from '@/abis/index';

console.log(CONTRACT_ADDRESSES.NFT_CONTRACT); // ✅ Works
console.log(NETWORK_CONFIG.CHAIN_ID); // ✅ Works
```

These now dynamically return values from the current chain via getters.

## Deployment Guide

### Deploying Contracts to New Chains

1. **Deploy NFT Contract:**
```bash
# Example using Hardhat
npx hardhat run scripts/deploy-nft.ts --network sepolia
```

2. **Deploy Staking Contract:**
```bash
npx hardhat run scripts/deploy-staking.ts --network sepolia
```

3. **Update `.env`:**
```env
VITE_SEPOLIA_NFT_CONTRACT=0xDeployedNFTAddress
VITE_SEPOLIA_STAKING_CONTRACT=0xDeployedStakingAddress
```

4. **Rebuild application:**
```bash
npm run build
```

### Contract Deployment Checklist

For each new chain:
- [ ] Deploy NFT contract
- [ ] Deploy Staking contract
- [ ] Verify contracts on block explorer
- [ ] Test minting functionality
- [ ] Test staking functionality
- [ ] Update environment variables
- [ ] Test chain switching in UI
- [ ] Document contract addresses

## Testing

### Test Chain Switching

```typescript
// Test all chains
import { SUPPORTED_CHAINS } from '@/config/chains';

for (const [key, chain] of Object.entries(SUPPORTED_CHAINS)) {
  try {
    await chainManager.switchChain(key);
    console.log(`✅ ${chain.name} - OK`);
  } catch (error) {
    console.error(`❌ ${chain.name} - Failed:`, error);
  }
}
```

### Test Contract Availability

```typescript
import { chainManager } from '@/services/ChainManagerService';

// Check which chains have contracts configured
Object.values(SUPPORTED_CHAINS).forEach(chain => {
  const hasContracts = !!(chain.contracts?.nftContract && chain.contracts?.stakingContract);
  console.log(`${chain.name}: ${hasContracts ? '✅' : '❌'}`);
});
```

## Migration Notes

### From Single-Chain to Multi-Chain

**Before:**
```typescript
const contractAddress = '0x5Bb23220cC12585264fCd144C448eF222c8572A2';
const rpcUrl = 'https://rpc-amoy.polygon.technology/';
```

**After:**
```typescript
const contractAddress = chainManager.getContractAddresses().nftContract;
const rpcUrls = chainManager.getRpcUrls();
```

### Service Updates

All services automatically get current chain info:

```typescript
// Old
constructor() {
  this.contractAddress = HARDCODED_ADDRESS;
}

// New
constructor() {
  this.currentChain = chainManager.getCurrentChain();
  this.contractAddress = this.currentChain.contracts?.nftContract || '';
  
  // Listen for changes
  chainManager.onChainChange((newChain) => {
    this.currentChain = newChain;
    this.reset(); // Reset service state
  });
}
```

## Troubleshooting

### "Wrong network" Warning

**Cause:** MetaMask is on a different chain than selected in UI

**Solution:**
```typescript
// Auto-switch MetaMask to correct network
await chainManager.switchChain('POLYGON_AMOY');
```

### "Contracts not configured" Warning

**Cause:** Contract addresses not set for selected chain

**Solution:**
1. Deploy contracts to that chain
2. Add addresses to `.env`
3. Rebuild application

### Chain Switch Rejected

**Cause:** User rejected MetaMask popup

**Solution:** No action needed - user cancelled intentionally

### RPC Errors

**Cause:** RPC endpoint down or rate-limited

**Solution:** System automatically tries fallback RPCs defined in `chains.ts`

## Best Practices

1. **Always check contracts are configured:**
```typescript
if (!chainManager.hasContractsConfigured()) {
  toast.error('Contracts not deployed on this network');
  return;
}
```

2. **Listen for chain changes:**
```typescript
useEffect(() => {
  return chainManager.onChainChange(() => {
    // Reload data for new chain
    refetchData();
  });
}, []);
```

3. **Handle network mismatches:**
```typescript
if (!await chainManager.isOnCorrectNetwork()) {
  await chainManager.switchChain('POLYGON_AMOY');
}
```

4. **Provide fallback RPC URLs:**
Each chain has multiple RPC endpoints for reliability.

## Performance Considerations

- **Chain persistence:** Selected chain saved to localStorage
- **Lazy initialization:** Services initialize on first use
- **Event-driven:** Components update only when chain changes
- **RPC fallbacks:** Automatic failover to backup RPCs

## Security Considerations

- ✅ All chain switches require MetaMask user approval
- ✅ Contract addresses stored in environment variables
- ✅ RPC endpoints use HTTPS
- ✅ Chain IDs verified before transactions
- ✅ No private keys in frontend code

## Future Enhancements

- [ ] Add mainnet support (when ready)
- [ ] Custom RPC URL input
- [ ] Chain health monitoring
- [ ] Gas price optimization per chain
- [ ] Multi-chain transaction history
- [ ] Cross-chain bridge integration

## Support

For issues or questions:
1. Check this documentation
2. Review console logs (detailed logging enabled)
3. Check MetaMask network settings
4. Verify contract addresses in `.env`

## Summary

Your application now supports **10 EVM testnets** with:
- ✅ Seamless chain switching
- ✅ Automatic network detection
- ✅ Persistent chain selection
- ✅ Full backward compatibility
- ✅ Easy to add new chains

**Next Steps:**
1. Add chain selector to your UI
2. Deploy contracts to additional chains
3. Test on each supported network
4. Update documentation with deployed addresses
