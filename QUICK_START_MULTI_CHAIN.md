# Quick Start: Multi-Chain Implementation

## What Changed?

Your application now supports **10 EVM testnets** instead of just Polygon Amoy!

## Immediate Setup

### 1. Add Chain Selector to Your UI

Add this to your navbar or header:

```tsx
import { ChainSelector } from '@/components/ChainSelector';

// In your header/navbar component
<ChainSelector showFullName={true} />
```

### 2. Check Current Implementation

All existing code **continues to work** without changes! The system is backward compatible.

But for new features, use:

```tsx
import { useChain } from '@/hooks/useChain';

function MyComponent() {
  const { currentChain, hasContracts, isCorrectNetwork } = useChain();
  
  return (
    <div>
      <p>Current Network: {currentChain.name}</p>
      {!hasContracts && <Alert>Contracts not deployed here yet</Alert>}
      {!isCorrectNetwork && <Alert>Please switch network in MetaMask</Alert>}
    </div>
  );
}
```

## Deploying to New Chains

### Step 1: Deploy Your Contracts

For each chain you want to support, deploy your NFT and Staking contracts.

Example for Sepolia:
```bash
# Deploy NFT contract
npx hardhat run scripts/deploy-nft.ts --network sepolia

# Deploy Staking contract
npx hardhat run scripts/deploy-staking.ts --network sepolia
```

### Step 2: Add Contract Addresses to .env

```env
# Polygon Amoy (already configured)
VITE_POLYGON_NFT_CONTRACT=0x5Bb23220cC12585264fCd144C448eF222c8572A2
VITE_POLYGON_STAKING_CONTRACT=0x1F2Dbf590b1c4C96c1ddb4FF55002Dbb33DA294e

# Ethereum Sepolia (add your deployed addresses)
VITE_SEPOLIA_NFT_CONTRACT=0xYourDeployedNFTContract
VITE_SEPOLIA_STAKING_CONTRACT=0xYourDeployedStakingContract

# BSC Testnet
VITE_BSC_NFT_CONTRACT=0xYourDeployedNFTContract
VITE_BSC_STAKING_CONTRACT=0xYourDeployedStakingContract

# Add more as needed...
```

### Step 3: Rebuild

```bash
npm run build
```

That's it! Your app now works on the new chain.

## Key Files Created

| File | Purpose |
|------|---------|
| `src/config/chains.ts` | Configuration for all 10 chains |
| `src/services/ChainManagerService.ts` | Chain switching logic |
| `src/components/ChainSelector.tsx` | UI component for chain selection |
| `src/hooks/useChain.ts` | React hook for chain management |
| `MULTI_CHAIN_IMPLEMENTATION.md` | Full documentation |

## Key Files Updated

| File | Changes |
|------|---------|
| `src/abis/index.ts` | Now uses dynamic chain config |
| `src/services/Web3MetaMaskNFTService.ts` | Multi-chain aware |
| `src/services/EnhancedHybridBurnService.ts` | Multi-chain aware |
| `src/services/ImprovedOnchainStakingService.ts` | Multi-chain aware |

## Supported Networks (Out of the Box)

1. ✅ **Polygon Amoy** - Already configured
2. **Ethereum Sepolia** - Add contracts
3. **BSC Testnet** - Add contracts  
4. **Avalanche Fuji** - Add contracts
5. **Arbitrum Sepolia** - Add contracts
6. **Optimism Sepolia** - Add contracts
7. **Base Sepolia** - Add contracts
8. **Fantom Testnet** - Add contracts
9. **Scroll Sepolia** - Add contracts
10. **Linea Sepolia** - Add contracts

## Testing Your Implementation

### Test 1: Chain Switching

1. Open your app
2. Click the chain selector
3. Select a different network
4. MetaMask should prompt to switch
5. Approve the switch
6. UI should update automatically

### Test 2: Service Functionality

```typescript
// In browser console
import { chainManager } from '@/services/ChainManagerService';

// Check current chain
console.log(chainManager.getCurrentChain());

// Check contracts are configured
console.log(chainManager.hasContractsConfigured());

// Get contract addresses
console.log(chainManager.getContractAddresses());
```

### Test 3: Wrong Network Detection

1. Switch network in MetaMask manually
2. App should detect the mismatch
3. Chain selector should show warning icon
4. Clicking chain selector should offer to switch back

## Common Issues & Solutions

### Issue: "Contracts not configured"

**Cause:** You haven't deployed contracts to that chain yet

**Solution:** Either:
- Deploy contracts and add addresses to `.env`
- Or stick to Polygon Amoy (already configured)

### Issue: MetaMask chain switch fails

**Cause:** User rejected or chain not added to MetaMask

**Solution:** The app automatically adds the chain if needed. User just needs to approve.

### Issue: Service errors after switching

**Cause:** Service state not reset

**Solution:** Already handled! Services listen for chain changes and reset automatically.

## Integration Checklist

- [ ] Add `ChainSelector` component to your UI
- [ ] Test chain switching with MetaMask
- [ ] Deploy contracts to desired chains (optional)
- [ ] Add contract addresses to `.env` (for new chains)
- [ ] Test all major features on each chain
- [ ] Update user documentation

## Next Steps

1. **For Production:**
   - Deploy contracts to all chains you want to support
   - Update `.env` with production contract addresses
   - Test thoroughly on each chain
   - Consider adding mainnet support later

2. **For Development:**
   - Use Polygon Amoy (already working)
   - Add other chains as needed
   - Test multi-chain scenarios

3. **For Users:**
   - Add chain selector to visible location
   - Show warnings when contracts not available
   - Guide users to switch networks when needed

## Benefits of Multi-Chain

- ✅ **User Choice:** Users can choose their preferred network
- ✅ **Lower Costs:** Some chains have lower gas fees
- ✅ **Better UX:** No need to bridge assets
- ✅ **Future-Proof:** Easy to add more chains later
- ✅ **Broader Reach:** Access users on different ecosystems

## Need Help?

See `MULTI_CHAIN_IMPLEMENTATION.md` for:
- Detailed architecture explanation
- Advanced usage examples
- Troubleshooting guide
- Best practices
- API reference

---

**Your app is now multi-chain ready!** 🚀

Start by adding the `ChainSelector` component to your UI, then deploy contracts to additional chains as needed.
