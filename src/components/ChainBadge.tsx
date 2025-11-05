/**
 * ChainBadge Component
 * Displays blockchain network logo badge on NFT images
 * Shows which chain the NFT belongs to (Polygon, Ethereum, BSC, etc.)
 */

import React from 'react';
import { getChainByNetwork, getChainById } from '@/config/chains';

interface ChainBadgeProps {
  blockchain?: string; // Network name (e.g., 'polygon-amoy', 'sepolia')
  chainId?: number; // Chain ID
  chainName?: string; // Human-readable chain name
  chainIconUrl?: string; // Direct icon URL
  size?: 'xs' | 'sm' | 'md' | 'lg'; // Badge size
  position?: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'; // Badge position
  className?: string;
}

export const ChainBadge: React.FC<ChainBadgeProps> = ({
  blockchain,
  chainId,
  chainName,
  chainIconUrl,
  size = 'md',
  position = 'top-right',
  className = '',
}) => {
  // Get chain config from blockchain or chainId
  const chainConfig = blockchain 
    ? getChainByNetwork(blockchain) 
    : chainId 
    ? getChainById(chainId) 
    : null;

  // Determine icon URL and name
  const iconUrl = chainIconUrl || chainConfig?.iconUrl;
  const name = chainName || chainConfig?.name || 'Unknown Chain';
  const network = blockchain || chainConfig?.network || '';

  // Don't render if no chain info available
  if (!iconUrl && !chainConfig) {
    return null;
  }

  // Size classes - increased for better visibility
  const sizeClasses = {
    xs: 'w-5 h-5',
    sm: 'w-7 h-7',
    md: 'w-10 h-10',
    lg: 'w-12 h-12',
  };

  // Icon size within badge
  const iconSizeClasses = {
    xs: 'w-5 h-5',
    sm: 'w-7 h-7',
    md: 'w-10 h-10',
    lg: 'w-12 h-12',
  };

  // Position classes
  const positionClasses = {
    'top-left': 'top-3 left-3',
    'top-right': 'top-3 right-3',
    'bottom-left': 'bottom-3 left-3',
    'bottom-right': 'bottom-3 right-3',
  };

  // Chain-specific gradient backgrounds and glow colors for modern look
  const getChainStyles = (network: string) => {
    switch (network) {
      case 'polygon-amoy':
        return {
          gradient: 'from-purple-500 via-purple-600 to-purple-700',
          glow: 'shadow-[0_0_30px_rgba(168,85,247,0.9),0_0_50px_rgba(168,85,247,0.5),0_0_70px_rgba(168,85,247,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(168,85,247,1),0_0_60px_rgba(168,85,247,0.7),0_0_80px_rgba(168,85,247,0.4)]',
        };
      case 'sepolia':
        return {
          gradient: 'from-blue-500 via-blue-600 to-blue-700',
          glow: 'shadow-[0_0_30px_rgba(59,130,246,0.9),0_0_50px_rgba(59,130,246,0.5),0_0_70px_rgba(59,130,246,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(59,130,246,1),0_0_60px_rgba(59,130,246,0.7),0_0_80px_rgba(59,130,246,0.4)]',
        };
      case 'bsc-testnet':
        return {
          gradient: 'from-yellow-400 via-yellow-500 to-yellow-600',
          glow: 'shadow-[0_0_30px_rgba(234,179,8,0.9),0_0_50px_rgba(234,179,8,0.5),0_0_70px_rgba(234,179,8,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(234,179,8,1),0_0_60px_rgba(234,179,8,0.7),0_0_80px_rgba(234,179,8,0.4)]',
        };
      case 'arbitrum-sepolia':
        return {
          gradient: 'from-blue-400 via-blue-500 to-blue-600',
          glow: 'shadow-[0_0_30px_rgba(96,165,250,0.9),0_0_50px_rgba(96,165,250,0.5),0_0_70px_rgba(96,165,250,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(96,165,250,1),0_0_60px_rgba(96,165,250,0.7),0_0_80px_rgba(96,165,250,0.4)]',
        };
      case 'optimism-sepolia':
        return {
          gradient: 'from-red-500 via-red-600 to-red-700',
          glow: 'shadow-[0_0_30px_rgba(239,68,68,0.9),0_0_50px_rgba(239,68,68,0.5),0_0_70px_rgba(239,68,68,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(239,68,68,1),0_0_60px_rgba(239,68,68,0.7),0_0_80px_rgba(239,68,68,0.4)]',
        };
      case 'base-sepolia':
        return {
          gradient: 'from-blue-600 via-blue-700 to-blue-800',
          glow: 'shadow-[0_0_30px_rgba(37,99,235,0.9),0_0_50px_rgba(37,99,235,0.5),0_0_70px_rgba(37,99,235,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(37,99,235,1),0_0_60px_rgba(37,99,235,0.7),0_0_80px_rgba(37,99,235,0.4)]',
        };
      case 'avalanche-fuji':
        return {
          gradient: 'from-red-500 via-red-600 to-red-700',
          glow: 'shadow-[0_0_30px_rgba(220,38,38,0.9),0_0_50px_rgba(220,38,38,0.5),0_0_70px_rgba(220,38,38,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(220,38,38,1),0_0_60px_rgba(220,38,38,0.7),0_0_80px_rgba(220,38,38,0.4)]',
        };
      default:
        return {
          gradient: 'from-gray-600 via-gray-700 to-gray-800',
          glow: 'shadow-[0_0_30px_rgba(75,85,99,0.9),0_0_50px_rgba(75,85,99,0.5),0_0_70px_rgba(75,85,99,0.3)]',
          hoverGlow: 'hover:shadow-[0_0_35px_rgba(75,85,99,1),0_0_60px_rgba(75,85,99,0.7),0_0_80px_rgba(75,85,99,0.4)]',
        };
    }
  };

  const chainStyles = getChainStyles(network);

  return (
    <div
      className={`absolute ${positionClasses[position]} ${className} z-10 group`}
      title={name}
    >
      {/* Outer container with strong backdrop shadow */}
      <div className="relative">
        {/* Dark backdrop for contrast */}
        <div className="absolute inset-0 bg-black/60 rounded-full blur-lg scale-110" />
        
        {/* Glow effect layer */}
        <div
          className={`
            rounded-full
            relative
            ${chainStyles.glow}
            ${chainStyles.hoverGlow}
            transition-all duration-300
            hover:scale-110
          `}
        >
          {/* Outer ring with gradient */}
          <div className={`w-full h-full bg-gradient-to-br ${chainStyles.gradient} rounded-full shadow-inner overflow-hidden`}>
              
              {/* Logo container with glow */}
              <div className="w-full h-full flex items-center justify-center relative z-10 ">
                {iconUrl ? (
                  <div className="relative w-full h-full flex items-center justify-center">
                    {/* Logo glow effect */}
                    <div className="absolute inset-0 flex items-center justify-center">
                      <img
                        src={iconUrl}
                        alt={`${name} glow`}
                        className={`${iconSizeClasses[size]} object-contain blur-sm opacity-60 scale-110`}
                      />
                    </div>
                    {/* Main logo */}
                    <img
                      src={iconUrl}
                      alt={name}
                      className={`
                        ${iconSizeClasses[size]} 
                        object-contain 
                        relative z-10
                        brightness-125 
                        contrast-125
                        saturate-125
                      `}
                      style={{
                        filter: 'brightness(1.25) contrast(1.25) saturate(1.25) drop-shadow(0 0 4px rgba(255,255,255,0.5)) drop-shadow(0 2px 8px rgba(0,0,0,0.9))'
                      }}
                      onError={(e) => {
                        // Fallback to text if image fails to load
                        e.currentTarget.style.display = 'none';
                        const parent = e.currentTarget.parentElement?.parentElement;
                        if (parent) {
                          parent.innerHTML = `<span class="text-white text-sm font-black" style="filter: drop-shadow(0 0 8px rgba(255,255,255,0.5)) drop-shadow(0 2px 4px rgba(0,0,0,0.9))">${network.charAt(0).toUpperCase()}</span>`;
                        }
                      }}
                    />
                  </div>
                ) : (
                  <span 
                    className="text-white text-sm font-black"
                    style={{
                      filter: 'drop-shadow(0 0 8px rgba(255,255,255,0.5)) drop-shadow(0 2px 4px rgba(0,0,0,0.9))'
                    }}
                  >
                    {network.charAt(0).toUpperCase()}
                  </span>
                )}
              </div>
            </div>
          </div>
      </div>

      {/* Enhanced tooltip on hover */}
      <div
        className="
          absolute top-full right-0 mt-2
          opacity-0 group-hover:opacity-100
          transition-all duration-200
          pointer-events-none
          whitespace-nowrap
          z-20
          transform translate-y-0 group-hover:translate-y-1
        "
      >
        <div className="bg-gradient-to-br from-gray-900 to-gray-800 text-white text-xs px-3 py-1.5 rounded-lg shadow-xl border border-gray-700/50 backdrop-blur-sm">
          <div className="font-medium">{name}</div>
        </div>
        {/* Tooltip arrow */}
        <div className="absolute -top-1 right-3 w-2 h-2 bg-gray-900 transform rotate-45 border-l border-t border-gray-700/50" />
      </div>
    </div>
  );
};

/**
 * Helper function to extract chain info from NFT
 */
export const getChainInfoFromNFT = (nft: any) => {
  return {
    blockchain: nft.blockchain || nft.claimed_blockchain,
    chainId: nft.chainId,
    chainName: nft.chainName,
    chainIconUrl: nft.chainIconUrl,
  };
};
