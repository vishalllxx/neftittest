import { motion } from "framer-motion";
import { useState, useEffect, useRef } from "react";
import { NFTData } from "@/services/HybridIPFSService";
import { chainManager } from '@/services/ChainManagerService';
import { SUPPORTED_CHAINS, ChainConfig } from '@/config/chains';
import { useNFTContext } from '../../contexts/NFTContext';
import { useNFTOperations } from "@/hooks/useNFTOperations";
import { useChainValidatedClaim } from "@/hooks/useChainValidatedClaim";
import { useAutoChainSwitch } from "@/hooks/useAutoChainSwitch";
import { XCircle, ExternalLink, Lock, Loader2, Zap, CheckCircle, Cloud, Link, ChevronDown, Shield, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { web3MetaMaskNFTService } from '../../services/Web3MetaMaskNFTService';
import { useAuthState } from '../../hooks/useAuthState';
import { toast } from "react-hot-toast";
import { supabase } from "@/lib/supabase";
import ClaimedNFTDisplay from '../nft/ClaimedNFTDisplay';
import { useClaimedNFTs } from '../../hooks/useClaimedNFTs';
import { nftLifecycleService, OffchainNFT, OnchainNFT } from '../../services/NFTLifecycleService';
import ProgressiveNFTImage from '../ui/ProgressiveNFTImage';
import { getIPFSUrl, extractIPFSHash } from '../../config/ipfsConfig';
import { useEnsureNFTsLoaded } from '../../hooks/useEnsureNFTsLoaded';
import { cn } from "@/lib/utils";
import { ChainBadge } from '@/components/ChainBadge';
import { useIsMobile } from '@/hooks/use-mobile';

interface NFTDetailsModalProps {
  isOpen: boolean;
  onClose: () => void;
  nft: NFTData | null;
  walletAddress?: string;
}

// Helper: Find chain by contract address
const getChainByContractAddress = (contractAddress: string | undefined): ChainConfig | null => {
  if (!contractAddress) return null;
  
  const normalizedAddress = contractAddress.toLowerCase();
  
  for (const chain of Object.values(SUPPORTED_CHAINS)) {
    if (chain.contracts?.nftContract?.toLowerCase() === normalizedAddress) {
      return chain;
    }
  }
  
  return null;
};

const NFTDetailsModal = ({ isOpen, onClose, nft, walletAddress }: NFTDetailsModalProps) => {
  const [claimDetails, setClaimDetails] = useState<any>(null);

  // Debug NFT ownership and transfer issues
  const debugOwnership = async () => {
    if (!nft?.id) return;
    
    const tokenId = claimDetails?.token_id;
    if (!tokenId) {
      console.log("❌ No token ID found for this NFT");
      return;
    }
    
    console.log(`🔍 Debugging transfer issues for NFT ${nft.id}, Token ID: ${tokenId}`);
    await web3MetaMaskNFTService.debugNFTOwnership(tokenId);
  };

  // Make debug function globally available
  if (typeof window !== 'undefined') {
    (window as any).debugNFT12 = () => web3MetaMaskNFTService.debugNFTOwnership("12");
  }

  // Load claim details from database when modal opens
  useEffect(() => {
    const loadClaimDetails = async () => {
      if (!isOpen || !nft || !walletAddress) return;
      
      try {
        // Use database query directly instead of SimpleNFTMintService
        const { data: claims } = await supabase
          .from('nft_claims')
          .select('*')
          .eq('wallet_address', walletAddress.toLowerCase());
        const claimData = claims.find((claim: any) => claim.nft_id === nft.id);
        setClaimDetails(claimData);
        console.log("🔍 Loaded claim details for NFT:", claimData);
      } catch (error) {
        console.error("Failed to load claim details:", error);
      }
    };

    loadClaimDetails();
  }, [isOpen, nft?.id, walletAddress]);

  if (!isOpen || !nft) return null;

  // Use claim details from database if available, fallback to NFT object
  const tokenId = claimDetails?.token_id || nft.tokenId;
  const transactionHash = claimDetails?.transaction_hash || nft.transactionHash;
  const contractAddress = claimDetails?.contract_address || nft.contractAddress;
  const claimedAt = claimDetails?.claimed_at;

  // Dynamically determine chain from contract address
  const nftChain = getChainByContractAddress(contractAddress);
  const chainName = nftChain?.name || 'Unknown Chain';
  const blockExplorerUrl = nftChain?.blockExplorerUrls[0] || '#';

  // Debug: Log NFT data when modal opens
  console.log("🔍 NFT Details Modal - Combined Data:", {
    id: nft.id,
    name: nft.name,
    tokenId,
    transactionHash,
    contractAddress,
    detectedChain: chainName,
    onChain: nft.onChain,
    claimDetails
  });

  // Format address to show first 4 and last 4 characters
  const formatAddress = (address: string) => {
    if (!address) return '';
    return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
  };


  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className=" bg-gradient-to-b from-[#121021] to-[#5D43EF]/20 rounded-xl p-6 w-full max-w-md relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white transition-colors"
        >
          <XCircle className="h-6 w-6" />
        </button>
        
       
        <div className="border-b border-[#5d43ef]/20  mb-6 ">
          <h3 className="text-white font-medium mb-2">{nft.name}</h3>
          {/* Description removed per user request */}
        </div>
        
        <div className="space-y-4 text-left">
          {/* Only show contract address if NFT is claimed (has contractAddress) */}
          {contractAddress && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Contract Address</span>
              <span className="text-white font-mono">{formatAddress(contractAddress)}</span>
            </div>
          )}
          
          <div className="flex justify-between items-center pb-2">
            <span className="text-gray-400">Token ID</span>
            <span className="text-white">
              {tokenId || 'Not Claimed'}
            </span>
          </div>
          
          {/* Only show token standard if NFT is claimed */}
          {contractAddress && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Token Standard</span>
              <span className="text-white">ERC-721</span>
            </div>
          )}
          
          <div className="flex justify-between items-center pb-2">
            <span className="text-gray-400">Owner</span>
            <span className="text-white font-mono">{formatAddress(walletAddress || nft.wallet_address || nft.owner || '')}</span>
          </div>
          
          {/* Only show chain if NFT is claimed */}
          {contractAddress && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Chain</span>
              <span className="text-white">{chainName}</span>
            </div>
          )}
          
          {/* Show NFT status for offchain NFTs */}
          {!contractAddress && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Status</span>
              <div className="flex items-center gap-2">
                <Cloud className="h-4 w-4 text-blue-400" />
                <span className="text-blue-400">Offchain (Ready to Claim)</span>
              </div>
            </div>
          )}
          
          {/* Show rarity for all NFTs */}
          {nft.rarity && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Rarity</span>
              <span className="text-white capitalize">{nft.rarity}</span>
            </div>
          )}
          
          {claimedAt && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Claimed At</span>
              <span className="text-white text-sm">
                {new Date(claimedAt).toLocaleDateString('en-US', {
                  year: 'numeric',
                  month: 'short',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit'
                })}
              </span>
            </div>
          )}
          
          {transactionHash && (
            <div className="flex justify-between items-center pb-2">
              <span className="text-gray-400">Transaction Hash</span>
              <div className="flex items-center gap-2">
                <a 
                  href={`${blockExplorerUrl}tx/${transactionHash}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[#5D43EF] hover:text-[#7B61FF] font-mono text-sm transition-colors"
                >
                  {transactionHash.substring(0, 10)}...{transactionHash.substring(transactionHash.length - 8)}
                </a>
                <ExternalLink className="h-3 w-3 text-gray-400" />
              </div>
            </div>
          )}

          {claimDetails && (
            <div className="mt-4 p-3 bg-green-500/10 border border-green-500/20 rounded-lg">
              <div className="flex items-center gap-2 text-green-400 text-sm">
                <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Claimed on Blockchain</span>
              </div>
            </div>
          )}

        </div>
        
        
      </div>
    </div>
  );
};

// Type for NFTs with staking status
interface NFTDataWithStaking extends NFTData {
  isStaked?: boolean;
}

// Combined NFT type for display
type DisplayNFT = (OffchainNFT | OnchainNFT) & {
  isStaked?: boolean;
  // Legacy properties for backward compatibility
  claimed?: boolean;
  onChain?: boolean;
  tokenId?: string;
  transactionHash?: string;
  contractAddress?: string;
  metadataURI?: string;
  // Claiming status for UI feedback
  claimingStatus?: 'claiming' | 'completed' | 'failed';
  // Multichain properties
  blockchain?: string; // Network identifier (e.g., 'polygon-amoy', 'sepolia')
  chainId?: number; // Chain ID for the blockchain
  chainName?: string; // Human-readable chain name
  chainIconUrl?: string; // Chain logo URL
  // Chain-specific distribution properties
  assigned_chain?: string; // Blockchain this NFT is assigned to (from CID pool distribution)
  chain_contract_address?: string; // Contract address on assigned chain
  can_claim_to_any_chain?: boolean; // If true, can claim to any chain; if false, only to assigned_chain
  ipfs_cid?: string; // IPFS CID for chain validation
};

interface MyNFTsProps {
  walletAddress?: string;
}

// Rarity styling function
const getRarityStyles = (rarity: string) => {
  const colors: Record<string, { bg: string; text: string; border: string }> = {
    Common: {
      bg: "bg-gray-700",
      text: "text-gray-300",
      border: "border-gray-600",
    },
    Rare: {
      bg: "bg-blue-800/30",
      text: "text-sky-400",
      border: "border-sky-700",
    },
    Legendary: {
      bg: "bg-amber-800/30",
      text: "text-amber-400",
      border: "border-amber-700",
    },
    Silver: {
      bg: "bg-slate-500/20",
      text: "text-slate-300",
      border: "border-slate-400",
    },
    Gold: {
      bg: "bg-yellow-700/30",
      text: "text-yellow-300",
      border: "border-yellow-600",
    },
    Platinum: {
      bg: "bg-indigo-800/20",
      text: "text-indigo-300",
      border: "border-indigo-700",
    },
  };

  return colors[rarity] || {
    bg: "bg-gray-700",
    text: "text-gray-300",
    border: "border-gray-600",
  };
};

// Helper function to store NFT claim in Supabase
const storeNFTClaimInSupabase = async (claimData: {
  nftId: string;
  walletAddress: string;
  transactionHash: string;
  contractAddress: string;
  tokenId: string;
  blockchainType: string;
}) => {
  try {
    // Get current user
    const { data: { user } } = await supabase.auth.getUser();
    
    const { error } = await supabase
      .from('nft_claims')
      .insert({
        nft_id: claimData.nftId,
        user_id: user?.id || null,
        wallet_address: claimData.walletAddress,
        claimed_blockchain: claimData.blockchainType,
        transaction_hash: claimData.transactionHash,
        contract_address: claimData.contractAddress,
        token_id: claimData.tokenId,
        blockchain_type: claimData.blockchainType
      });

    if (error) {
      console.error("❌ Error storing NFT claim in Supabase:", error);
      throw error;
    }

    console.log("✅ NFT claim stored in Supabase successfully");
    return true;
  } catch (error) {
    console.error("❌ Failed to store NFT claim in Supabase:", error);
    return false;
  }
};

// Helper function to load NFT claims from Supabase
const loadNFTClaimsFromSupabase = async (walletAddress: string) => {
  try {
    const { data, error } = await supabase
      .from('nft_claims')
      .select('*')
      .eq('wallet_address', walletAddress);

    if (error) {
      console.error("❌ Error loading NFT claims from Supabase:", error);
      return [];
    }

    console.log("📦 Loaded NFT claims from Supabase:", data?.length || 0);
    return data || [];
  } catch (error) {
    console.error("❌ Failed to load NFT claims from Supabase:", error);
    return [];
  }
};

const MyNFTs = ({ walletAddress }: MyNFTsProps) => {
  const [selectedNft, setSelectedNft] = useState<NFTData | null>(null);
  const { walletAddress: userWallet, isAuthenticated } = useAuthState();
  const [isModalOpen, setIsModalOpen] = useState(false);
  
  // Ensure NFTs are loaded when component mounts
  const { isLoading: nftAutoLoading, hasNFTs } = useEnsureNFTsLoaded();
  const [claimedNfts, setClaimedNfts] = useState<Set<string>>(new Set());
  const [mintingNfts, setMintingNfts] = useState<Set<string>>(new Set());
  const isMobile = useIsMobile();
  
  // NFT Context - centralized NFT management
  const { 
    allNFTs, 
    availableNFTs,
    stakedNFTs,
    isLoading: isLoadingNFTsContext,
    isInitialized: nftContextInitialized,
    isLoadingMore,
    hasMoreToLoad,
    loadingProgress,
    syncNFTCountsToBackend
  } = useNFTContext();
  
  // NFT Operations with optimistic updates
  const { claimNFT } = useNFTOperations();
  
  // Local state for display and filtering
  const [displayNFTs, setDisplayNFTs] = useState<DisplayNFT[]>([]);
  const [viewMode, setViewMode] = useState<'all' | 'offchain' | 'onchain'>('all');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const [chainViewMode, setChainViewMode] = useState<'all' | 'polygon-amoy' | 'sepolia' | 'bsc-testnet' | 'avalanche-fuji' | 'arbitrum-sepolia' | 'optimism-sepolia' | 'base-sepolia'>('all');
  const [chainIsDropdownOpen, setChainIsDropdownOpen] = useState(false);
  const chainDropdownRef = useRef<HTMLDivElement>(null);


  // Use the new claimed NFTs hook (optimized for low egress)
  const { claimedNFTs: persistentClaimedNFTs, stats, isLoading: isLoadingClaimed, refreshClaims } = useClaimedNFTs(walletAddress);

  // Use chain-validated claim hook
  const { claimWithValidation, checkChainCompatibility, isValidating } = useChainValidatedClaim();
  
  // Use auto chain switch hook
  const { switchToNFTChain } = useAutoChainSwitch();

  // NFTs are now loaded by NFTContext - no need for separate loading function
  // Update display NFTs when context NFTs change - OPTIMIZED
  useEffect(() => {
    if (allNFTs) {
      // OPTIMIZATION: Direct assignment instead of mapping (ContextNFT already has correct format)
      setDisplayNFTs(allNFTs);
    }
  }, [allNFTs]);

  // Update display NFTs based on view mode and chain filter (updated for context)
  const updateDisplayNFTs = (contextNFTs: any[], mode: 'all' | 'offchain' | 'onchain', chainFilter: 'all' | 'polygon-amoy' | 'sepolia' | 'bsc-testnet' | 'avalanche-fuji' | 'arbitrum-sepolia' | 'optimism-sepolia' | 'base-sepolia' = 'all') => {
    let filtered: DisplayNFT[] = [];
    
    // First filter by status (offchain/onchain)
    switch (mode) {
      case 'offchain':
        filtered = contextNFTs.filter(nft => nft.status === 'offchain');
        break;
      case 'onchain':
        filtered = contextNFTs.filter(nft => nft.status === 'onchain');
        break;
      case 'all':
      default:
        filtered = contextNFTs;
        break;
    }
    
    // Then filter by chain/network
    if (chainFilter !== 'all') {
      filtered = filtered.filter(nft => {
        // Get chain info from NFT
        let nftChain: string | undefined;
        
        if (nft.status === 'offchain') {
          // For offchain NFTs, check assigned_chain or blockchain
          nftChain = (nft as any).assigned_chain || (nft as any).blockchain;
          
          // Fallback: extract from attributes
          if (!nftChain && (nft as any).attributes) {
            const attrs = (nft as any).attributes;
            const chainAttr = attrs.find((attr: any) => attr.trait_type === 'Assigned Chain' || attr.trait_type === 'Chain');
            const chainName = chainAttr?.value;
            
            // Map chain names to network identifiers
            if (chainName) {
              if (chainName.toLowerCase().includes('ethereum')) nftChain = 'sepolia';
              else if (chainName.toLowerCase().includes('polygon')) nftChain = 'polygon-amoy';
              else if (chainName.toLowerCase().includes('optimism')) nftChain = 'optimism-sepolia';
              else if (chainName.toLowerCase().includes('bnb') || chainName.toLowerCase().includes('bsc')) nftChain = 'bsc-testnet';
              else if (chainName.toLowerCase().includes('avalanche')) nftChain = 'avalanche-fuji';
              else if (chainName.toLowerCase().includes('arbitrum')) nftChain = 'arbitrum-sepolia';
              else if (chainName.toLowerCase().includes('base')) nftChain = 'base-sepolia';
            }
          }
        } else {
          // For onchain NFTs, use blockchain property
          nftChain = nft.blockchain;
        }
        
        // Normalize chain identifier for comparison
        const normalizedChain = nftChain?.toLowerCase() || '';
        
        // Match against filter
        switch (chainFilter) {
          case 'polygon-amoy':
            return normalizedChain.includes('polygon');
          case 'sepolia':
            return normalizedChain.includes('sepolia') && !normalizedChain.includes('base') && !normalizedChain.includes('arbitrum') && !normalizedChain.includes('optimism');
          case 'bsc-testnet':
            return normalizedChain.includes('bsc') || normalizedChain.includes('bnb');
          case 'avalanche-fuji':
            return normalizedChain.includes('avalanche') || normalizedChain.includes('fuji');
          case 'arbitrum-sepolia':
            return normalizedChain.includes('arbitrum');
          case 'optimism-sepolia':
            return normalizedChain.includes('optimism');
          case 'base-sepolia':
            return normalizedChain.includes('base');
          default:
            return true;
        }
      });
    }
    
    setDisplayNFTs(filtered);
  };

  // Update display NFTs when view mode or chain filter changes
  useEffect(() => {
    if (allNFTs) {
      updateDisplayNFTs(allNFTs, viewMode, chainViewMode);
    }
  }, [viewMode, chainViewMode, allNFTs]);

  // Sync local claimed state with persistent data
  useEffect(() => {
    if (persistentClaimedNFTs.length > 0) {
      const claimedIds = new Set(persistentClaimedNFTs.map(claim => claim.nft_id));
      setClaimedNfts(claimedIds);
      
      // NFT data refresh is now handled by context
    }
  }, [persistentClaimedNFTs]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
      if (chainDropdownRef.current && !chainDropdownRef.current.contains(event.target as Node)) {
        setChainIsDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleNftClick = async (nft: DisplayNFT) => {
    // If NFT is claimed/on-chain, try to get fresh on-chain data
    if (nft.status === 'onchain' || (nft as any).claimed || (nft as any).onChain) {
      console.log("🔗 Fetching fresh on-chain data for claimed NFT:", nft.name);
      try {
        // Try to get on-chain data from localStorage claims
        const claimedKey = `claimed_nfts_${walletAddress}`;
        const localClaims = JSON.parse(localStorage.getItem(claimedKey) || '[]');
        const claimData = localClaims.find((claim: any) => claim.nftId === nft.id);
        
        if (claimData) {
          // Enhance NFT with on-chain data
          const enhancedNft = {
            ...nft,
            tokenId: claimData.tokenId,
            transactionHash: claimData.transactionHash,
            claimedAt: claimData.claimedAt,
            contractAddress: claimData.contractAddress,
            onChain: true,
            claimed: true
          };
          setSelectedNft(enhancedNft);
          console.log("✅ Enhanced NFT with on-chain data:", enhancedNft);
        } else {
          setSelectedNft(nft);
        }
      } catch (error) {
        console.error("Error getting on-chain data:", error);
        setSelectedNft(nft);
      }
    } else {
    setSelectedNft(nft);
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    // Small delay to allow the modal to close before resetting the selected NFT
    setTimeout(() => setSelectedNft(null), 300);
  };

  const handleClaim = async (nft: DisplayNFT, event: React.MouseEvent) => {
    event.stopPropagation();
    
    console.log("🎯 Claim button clicked for NFT:", nft);
    
    if (!walletAddress) {
      toast.error("Please connect your wallet first");
      return;
    }

    // Only allow claiming offchain NFTs
    if (nft.status !== 'offchain') {
      toast.error("This NFT is already claimed on blockchain");
      return;
    }

    // Prevent claiming staked NFTs
    if (nft.isStaked) {
      toast.error("Cannot claim staked NFTs. Please unstake first.");
      return;
    }

    // Check MetaMask availability
    if (!window.ethereum) {
      toast.error("MetaMask not detected. Please install MetaMask to continue.");
      return;
    }

    // Auto-switch to the correct chain for this NFT
    console.log("🔄 Auto-switching to NFT's chain...");
    const switchResult = await switchToNFTChain(nft, 'claim');
    
    if (!switchResult.success) {
      // If user cancelled, don't show error
      if (!switchResult.cancelled) {
        toast.error(switchResult.message || "Failed to switch to required chain");
      }
      return;
    }

    // Check if current chain has contracts deployed (after switch)
    const hasContracts = chainManager.hasContractsConfigured();
    const currentChain = chainManager.getCurrentChain();
    
    if (!hasContracts) {
      toast.error(`No contracts deployed on ${currentChain.name}. Please switch to a supported chain.`);
      return;
    }

    // Start claiming process
    setMintingNfts(prev => new Set(prev).add(nft.id));

    try {
      console.log("🚀 Starting chain-validated NFT claim...");
      
      // Use chain-validated claim with automatic chain switching
      const result = await claimWithValidation(nft as any, true);
      
      if (result.success) {
        // Optimistic UI update: Mark as claimed locally
        setClaimedNfts(prev => new Set(prev).add(nft.id));
        
        // Update selected NFT if it's the same one
        if (selectedNft?.id === nft.id && result.data?.onchainNFT) {
          setSelectedNft(result.data.onchainNFT as NFTData);
        }

        // Sync NFT counts to backend for leaderboard after successful claim
        setTimeout(() => {
          syncNFTCountsToBackend();
        }, 1000);

        toast.success(result.message || `${nft.name} claimed to blockchain successfully!`);
      } else {
        toast.error(result.message || "Failed to claim NFT");
      }
    } catch (error: any) {
      console.error("❌ NFT claim error:", error);
      
      if (error.message?.includes("Claim limit exceeded") || error.message?.includes("DropClaimExceedLimit")) {
        toast.error("🚨 Claim Limit Reached! You have already claimed the maximum number of NFTs allowed.");
      } else {
        toast.error(error.message || "Failed to claim NFT");
      }
    } finally {
      setMintingNfts(prev => {
        const newSet = new Set(prev);
        newSet.delete(nft.id);
        return newSet;
      });
    }
  };

  return (
    <div className="mt-0">
      <div className="bg-[#121021] border border-[#5d43ef]/20 rounded-xl py-6 px-2 sm:px-6">
        <div className="flex flex-col md:flex-row justify-between items-center lg:items-start mb-6">
          <div className="w-full mb-6 text-left">
            <h2 className="text-lg md:text-2xl font-bold text-white mb-2">
              My NFTs
            </h2>
            <p className="text-gray-400 text-xs md:text-base">Your collected digital assets and achievements</p>
            {(isLoadingNFTsContext || !loadingProgress.onchain) && (
              <div className="mt-2 text-xs bg-blue-500/20 text-blue-400 px-3 py-2 rounded flex items-center gap-2">
                <Loader2 className="w-3 h-3 animate-spin" />
                Loading your on-chain NFTs… This may take a few moments. Please ensure your wallet is connected.
              </div>
            )}
          </div>
          
          {/* Enhanced Tab Navigation with Dropdown */}
          <div className="flex justify-between gap-3 items-start">
            
            {/* Network Filter Dropdown */}
            <div className="relative" ref={chainDropdownRef}>
              <button
                onClick={() => {
                  setChainIsDropdownOpen(!chainIsDropdownOpen);
                }}
                className={`px-3 py-2 sm:px-4 sm:py-2 rounded-lg font-sora text-xs sm:text-sm flex-1 sm:flex-none ${
                  chainViewMode === 'all'
                    ? 'bg-gradient-to-t from-[#5d43ef] via-[#5d43ef]/80 to-[rgb(167,172,236)] text-white'
                    : 'bg-[#5d43ef] text-white'
                }`}
              >
                <span className="flex items-center gap-1 sm:gap-2 justify-end min-w-0">
                  <span className="truncate">
                    {chainViewMode === 'all' ? 'All Networks' : 
                     chainViewMode === 'polygon-amoy' ? 'Polygon' : 
                     chainViewMode === 'sepolia' ? 'Ethereum' : 
                     chainViewMode === 'bsc-testnet' ? 'BSC' :
                     chainViewMode === 'avalanche-fuji' ? 'Avalanche' :
                     chainViewMode === 'arbitrum-sepolia' ? 'Arbitrum' :
                     chainViewMode === 'optimism-sepolia' ? 'Optimism' :
                     'Base'}
                  </span>
                  <ChevronDown className={`w-3 h-3 sm:w-4 sm:h-4 transition-transform duration-200 ${chainIsDropdownOpen ? 'rotate-180' : ''} flex-shrink-0`} />
                </span>
              </button>

              {/* Network Dropdown Menu */}
              {chainIsDropdownOpen && (
                <div className="absolute left-0 mt-2 w-44 bg-[#1a1a2e] border border-[#5d43ef]/20 rounded-lg shadow-lg z-50 overflow-hidden max-h-80 overflow-y-auto">
                  
                  <button
                    onClick={() => {
                      setChainViewMode('all');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'all'
                        ? 'bg-[#5d43ef]/20 text-[#5d43ef]'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">All Networks</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('polygon-amoy');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'polygon-amoy'
                        ? 'bg-purple-600/20 text-purple-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Polygon Amoy</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('sepolia');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'sepolia'
                        ? 'bg-blue-600/20 text-blue-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Ethereum Sepolia</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('bsc-testnet');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'bsc-testnet'
                        ? 'bg-yellow-600/20 text-yellow-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">BSC Testnet</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('avalanche-fuji');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'avalanche-fuji'
                        ? 'bg-red-600/20 text-red-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Avalanche Fuji</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('arbitrum-sepolia');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'arbitrum-sepolia'
                        ? 'bg-cyan-600/20 text-cyan-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Arbitrum Sepolia</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('optimism-sepolia');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'optimism-sepolia'
                        ? 'bg-red-500/20 text-red-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Optimism Sepolia</span>
                  </button>
                  
                  <button
                    onClick={() => {
                      setChainViewMode('base-sepolia');
                      setChainIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      chainViewMode === 'base-sepolia'
                        ? 'bg-indigo-600/20 text-indigo-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    <span className="flex-1 text-sm">Base Sepolia</span>
                  </button>
                </div>
              )}
            </div>

          <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => {
                  setIsDropdownOpen(!isDropdownOpen);
                }}
                className={`px-3 py-2 sm:px-4 sm:py-2 rounded-lg font-sora text-xs sm:text-sm flex-1 sm:flex-none ${
                  viewMode === 'all'
                    ? 'bg-gradient-to-t from-[#5d43ef] via-[#5d43ef]/80 to-[rgb(167,172,236)] text-white'
                    : 'bg-[#5d43ef] text-white'
                }`}
              >
                <span className="flex items-center gap-1 sm:gap-2 justify-end min-w-0">
                  <span className="truncate">{viewMode === 'all' ? 'All NFTs' : viewMode === 'offchain' ? 'Off-Chain' : 'On-Chain'}</span>
                  <ChevronDown className={`w-3 h-3 sm:w-4 sm:h-4 transition-transform duration-200 ${isDropdownOpen ? 'rotate-180' : ''} flex-shrink-0`} />
                </span>
              </button>

              {/* Dropdown Menu */}
              {isDropdownOpen && (
                <div className="absolute right-0 mt-2 w-32 bg-[#1a1a2e] border border-[#5d43ef]/20 rounded-lg shadow-lg z-50 overflow-hidden">
                 
                 <button
                    onClick={() => {
                      setViewMode('all');
                      setIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      viewMode === 'all'
                        ? 'bg-[#5d43ef]/20 text-[#5d43ef]'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    
                    <span className="flex-1">All NFTs</span>
                   
                  </button>
                 
                  <button
                    onClick={() => {
                      setViewMode('offchain');
                      setIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      viewMode === 'offchain'
                        ? 'bg-purple-600/20 text-purple-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    
                    <span className="flex-1">Off-Chain</span>
                   
                  </button>
                  
                  <button
                    onClick={() => {
                      setViewMode('onchain');
                      setIsDropdownOpen(false);
                    }}
                    className={`w-full flex items-center gap-2 px-4 py-2 text-left transition-all duration-200 ${
                      viewMode === 'onchain'
                        ? 'bg-emerald-600/20 text-emerald-300'
                        : 'text-gray-300 hover:bg-[#2a2a4e] hover:text-white'
                    }`}
                  >
                    
                    <span className="flex-1">On-Chain</span>
                   
                    
                  </button>
                </div>
              )}
            </div>         
            </div>
        </div>

        {/* STREAMING LOADING INDICATOR */}
        {isLoadingMore && (
          <div className="mb-4 flex items-center justify-center p-3 bg-[#0B0A14]/50 border border-[#5d43ef]/20 rounded-xl">
            <div className="flex items-center gap-2 text-sm text-gray-300">
              <div className="w-4 h-4 border-2 border-[#5d43ef] border-t-transparent rounded-full animate-spin"></div>
              Loading more NFTs...
            </div>
          </div>
        )}

        {isLoadingNFTsContext ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="relative rounded-2xl bg-[#0B0A14] border border-[#5d43ef]/20 shadow-lg backdrop-blur-xl p-0 flex flex-col items-stretch animate-pulse">
                {/* NFT Image Skeleton */}
                <div className="relative w-full aspect-square bg-[#0B0A14] rounded-t-2xl overflow-hidden flex items-center justify-center">
                  <div className="w-full h-full bg-gradient-to-br from-[#5d43ef]/10 to-[#0b0a14]/20" />
                </div>
                {/* NFT Info Skeleton */}
                <div className="flex-1 flex flex-col justify-between p-4">
                  <div className="mb-2 sm:mb-4">
                    <div className="flex items-center justify-between mb-2 sm:mb-4">
                      <div className="h-4 sm:h-5 bg-gray-800 rounded w-3/4"></div>
                      <div className="h-6 sm:h-7 bg-gray-800 rounded-full w-16 sm:w-20"></div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : displayNFTs.length > 0 ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6">
            {displayNFTs.map((nft) => {
              const rarityStyles = getRarityStyles(nft.rarity);
              // Check if NFT is claimed from multiple sources
              const isClaimedFromState = claimedNfts.has(nft.id);
              const isClaimedFromNFT = nft.status === 'onchain' || (nft as any).claimed || (nft as any).onChain;
              const isClaimed = isClaimedFromState || isClaimedFromNFT;
              const isStaked = nft.isStaked;
              
              // Get assigned chain directly from NFT properties (from distribution)
              let assignedChain: string | undefined;
              if (nft.status === 'offchain') {
                // Use direct properties from NFT (populated by OptimizedCIDPoolBurnService)
                assignedChain = (nft as any).assigned_chain || (nft as any).blockchain;
                
                // Fallback: Try to extract from attributes if not in direct properties
                if (!assignedChain && (nft as any).attributes) {
                  const attrs = (nft as any).attributes;
                  const chainAttr = attrs.find((attr: any) => attr.trait_type === 'Assigned Chain' || attr.trait_type === 'Chain');
                  const chainName = chainAttr?.value;
                  
                  // Map chain names to network identifiers used in chains.ts
                  if (chainName) {
                    if (chainName.toLowerCase().includes('ethereum')) assignedChain = 'sepolia';
                    else if (chainName.toLowerCase().includes('polygon')) assignedChain = 'polygon-amoy';
                    else if (chainName.toLowerCase().includes('optimism')) assignedChain = 'optimism-sepolia';
                    else if (chainName.toLowerCase().includes('bnb') || chainName.toLowerCase().includes('bsc')) assignedChain = 'bsc-testnet';
                    else if (chainName.toLowerCase().includes('avalanche')) assignedChain = 'avalanche-fuji';
                    else if (chainName.toLowerCase().includes('arbitrum')) assignedChain = 'arbitrum-sepolia';
                    else if (chainName.toLowerCase().includes('base')) assignedChain = 'base-sepolia';
                  }
                }
              }
              
              return (
                <div
                  key={nft.id}
                  className={cn(
                    "relative rounded-2xl bg-[#0B0A14] border border-[#5d43ef] shadow-lg backdrop-blur-xl p-0 flex flex-col items-stretch transition-transform",
                    nft.status === 'offchain' && !isStaked && "group",
                    isStaked ? "opacity-60 cursor-not-allowed" : "hover:scale-[1.025] hover:shadow-2xl cursor-pointer"
                  )}
                  onClick={() => handleNftClick(nft)}
                >
                  {/* NFT Image */}
                  <div className="relative w-full aspect-square bg-[#0B0A14] rounded-t-2xl overflow-hidden flex items-center justify-center">
                    <ProgressiveNFTImage
                      src={nft.image || ''}
                      fallbackUrls={(nft as any).fallback_images || []}
                      ipfsHash={(nft as any).ipfs_hash || extractIPFSHash(nft.image || '') || undefined}
                      alt={nft.name}
                      className={cn("w-full h-full object-cover transition-transform duration-300", !isStaked && "group-hover:scale-105")}
                   />
                    {/* Chain Badge - Shows assigned blockchain for OFFCHAIN NFTs only */}
                    {nft.status === 'offchain' && assignedChain && (
                      <ChainBadge
                        blockchain={assignedChain}
                        size={isMobile ? 'xs' : 'sm'}
                        position="top-right"
                        className="z-10"
                      />
                    )}

                     
                        {nft.status !== 'offchain' && (() => {
                        const onchainContract =
                          (nft as any).contractAddress ||
                          (nft as any).chain_contract_address ||
                          (nft as any).contractAddress; // legacy key fallback

                        const chainConfig = getChainByContractAddress(onchainContract);

                        return (
                          <ChainBadge
                            blockchain={nft.blockchain || chainConfig?.network}
                            chainId={nft.chainId || chainConfig?.chainId}
                            chainName={nft.chainName || chainConfig?.name}
                            chainIconUrl={nft.chainIconUrl || chainConfig?.iconUrl}
                            size={isMobile ? 'xs' : 'sm'}
                            position="top-right"
                            className="z-10"
                          />
                        );
                      })()}

                    {/* Staked Lock Overlay - Smaller, positioned at top */}
                    {isStaked && (
                      <div className="absolute inset-0 bg-gradient-to-br from-[#5d43ef]/90 via-[#5d43ef]/70 to-[#0b0a14]/80 flex items-center justify-center pt-4 backdrop-blur-sm pointer-events-none">
                        <div className="bg-gradient-to-r from-[#5d43ef] to-[#a7acec] text-white px-2 py-1 sm:px-4 sm:py-2 rounded-xl font-bold text-xs sm:text-sm flex items-center gap-2 shadow-lg border border-white/20">
                          <Lock className="w-4 h-4" />
                          STAKED
                        </div>
                      </div>
                    )}

                    {/* Claim Button - Left Side */}
                    <div
                      className={cn(`absolute hidden top-1/2 left-[35%] lg:left-[40%] z-10 transition-all duration-300 ease-in-out
                                 group-hover:block hover:scale-[1.2]`, mintingNfts.has(nft.id) || nft.claimingStatus === 'claiming' ? 'left-[25%]' : 'left-[35%] lg:left-[40%]')}
                    >
                      {nft.status === 'offchain' && (
                        <button
                          onClick={(e) => handleClaim(nft, e)}
                          disabled={mintingNfts.has(nft.id) || nft.claimingStatus === 'claiming'}
                          className={cn(`rounded-full px-2 sm:px-3 py-0.5 sm:py-1 text-[12px] sm:text-base lg:text-lg font-semibold transition-all duration-200 mt-0 leading-none align-middle inline-block ${
                            mintingNfts.has(nft.id) || nft.claimingStatus === 'claiming'
                              ? 'bg-yellow-500/20 text-yellow-300 group-hover:bg-yellow-700/30 group-hover:text-yellow-300 cursor-not-allowed'
                              : 'bg-blue-500/20 text-sky-200 group-hover:bg-blue-800/80 group-hover:text-sky-100 cursor-pointer'
                          }`, isStaked && 'cursor-not-allowed')}
                        >
                          {mintingNfts.has(nft.id) || nft.claimingStatus === 'claiming' ? (
                            <>
                              <Loader2 className="w-3 h-3 mr-1 inline animate-spin" />
                              Claiming...
                            </>
                          ) : (
                            'Claim'
                          )}
                        </button>
                      )}
                     
                    </div>

                    {/* Storage Status Badge - Right Side */}
                    <div className="absolute top-2 left-2 z-10">
                      <div className={`rounded-full px-2 sm:px-3 py-0.5 sm:py-1 text-[10px] sm:text-xs font-semibold cursor-default shadow-lg backdrop-blur-sm border mt-0 leading-none align-middle inline-block ${
                        nft.status === 'offchain' 
                          ? 'bg-purple-500/20 text-purple-100 border-purple-400/30'
                          : 'bg-emerald-500/20 text-emerald-100 border-emerald-400/30'
                      }`}>
                        {nft.status === 'offchain' ? (
                          nft.claimingStatus === 'claiming' ? 'Claiming...' : 'Offchain'
                        ) : (
                          'Onchain'
                        )}
                      </div>
                    </div>
                  </div>

                  {/* NFT Info */}
                  <div className="flex-1 flex flex-col justify-between py-2 lg:py-4 px-[5px]">
                      <div className="mb-2 flex flex-col items-center justify-center lg:flex-row lg:justify-between gap-2 lg:gap-0">
                        <div className="text-sm sm:text-base font-bold text-white text-center sm:text-left">
                          {nft.name}
                        </div>
                        <span
                          className={cn(
                            "px-3 py-1 rounded-xl text-xs font-bold shadow",
                            rarityStyles.bg,
                            rarityStyles.text
                          )}
                        >
                          {nft.rarity}
                        </span>
                      </div>
                   
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center py-12"
          >
            <div className="w-24 h-24 bg-[#5d43ef]/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg
                className="w-12 h-12 text-[#5d43ef]"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
            </div>
            <h3 className="text-xl font-medium text-white mb-2">
              No NFTs Yet
            </h3>
            <p className="text-gray-400">
              Complete quests to earn your first NFT!
            </p>
          </motion.div>
        )}

        {/* NFT Details Modal */}
        <NFTDetailsModal 
          isOpen={isModalOpen} 
          onClose={closeModal} 
          nft={selectedNft} 
          walletAddress={walletAddress}
        />
      </div>
    </div>
  );
};

export default MyNFTs;  

