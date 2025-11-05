/**
 * Chain Selector Component
 * Allows users to switch between different EVM testnets
 */

import React, { useState, useEffect } from 'react';
import { chainManager } from '../services/ChainManagerService';
import { SUPPORTED_CHAINS, type ChainConfig } from '../config/chains';
import { Network, ChevronDown, Check, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

interface ChainSelectorProps {
  className?: string;
  onChainChange?: (chain: ChainConfig) => void;
}

export const ChainSelector: React.FC<ChainSelectorProps> = ({ 
  className = '', 
  onChainChange 
}) => {
  const [currentChain, setCurrentChain] = useState<ChainConfig>(chainManager.getCurrentChain());
  const [isOpen, setIsOpen] = useState(false);
  const [isSwitching, setIsSwitching] = useState(false);
  const [isWrongNetwork, setIsWrongNetwork] = useState(false);

  useEffect(() => {
    // Listen for chain changes
    const unsubscribe = chainManager.onChainChange((newChain) => {
      setCurrentChain(newChain);
      if (onChainChange) {
        onChainChange(newChain);
      }
    });

    // Check if wallet is on correct network
    checkNetwork();

    return () => unsubscribe();
  }, [onChainChange]);

  const checkNetwork = async () => {
    const isCorrect = await chainManager.isOnCorrectNetwork();
    setIsWrongNetwork(!isCorrect);
  };

  const handleChainSwitch = async (chainKey: string) => {
    if (isSwitching) return;

    setIsSwitching(true);
    setIsOpen(false);

    const loadingToast = toast.loading(`Switching to ${SUPPORTED_CHAINS[chainKey].name}...`);

    try {
      await chainManager.switchChain(chainKey);
      // Dismiss loading toast immediately, show success briefly
      toast.success(`Switched to ${SUPPORTED_CHAINS[chainKey].name}`, { 
        id: loadingToast,
        duration: 2000 // Auto-dismiss after 2 seconds
      });
      setIsWrongNetwork(false);
    } catch (error: any) {
      console.error('Failed to switch chain:', error);
      
      if (error.code === 4001) {
        toast.error('Chain switch cancelled', { id: loadingToast });
      } else {
        toast.error(`Failed to switch chain: ${error.message}`, { id: loadingToast });
      }
    } finally {
      setIsSwitching(false);
    }
  };

  const getChainIcon = (chain: ChainConfig) => {
    if (chain.iconUrl) {
      return (
        <img 
          src={chain.iconUrl} 
          alt={chain.name} 
          className="w-5 h-5 rounded-full"
          onError={(e) => {
            // Fallback to Network icon if image fails to load
            (e.target as HTMLImageElement).style.display = 'none';
          }}
        />
      );
    }
    return <Network className="w-5 h-5" />;
  };

  const hasContracts = chainManager.hasContractsConfigured();

  return (
    <div className={`relative ${className}`}>
      {/* Current Chain Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        disabled={isSwitching}
        className={`
          flex items-center gap-2 px-2 md:px-3 md:py-2 py-1 rounded-lg
          bg-[#1b1930] border border-[#2D3748]/40
          hover:border-[#5d43ef]/50 hover:bg-[#1b1930]/80
          transition-all duration-200
          ${isSwitching ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
          ${isWrongNetwork ? 'border-red-500/50' : ''}
        `}
      >
        {getChainIcon(currentChain)}
      
          <span className="hidden lg:block text-white text-sm font-medium">
            {currentChain.name}
          </span>
      
        {isWrongNetwork && (
          <AlertCircle className="w-4 h-4 text-red-500" />
        )}
        {!hasContracts && (
          <span className="text-xs text-yellow-500">(No contracts)</span>
        )}
        <ChevronDown className={`w-4 h-4 text-gray-400 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <>
          {/* Backdrop */}
          <div 
            className="fixed inset-0 z-40" 
            onClick={() => setIsOpen(false)}
          />
          
          {/* Dropdown */}
          <div className="absolute top-full right-[-50px] md:right-0 mt-2 w-64 z-50 bg-[#1b1930] border border-[#2D3748]/40 rounded-lg shadow-xl overflow-hidden">
            <div className="p-2 border-b border-[#2D3748]/40">
              <p className="text-xs text-gray-400 px-2">Select Network</p>
            </div>
            
            <div className="max-h-96 overflow-y-auto">
              {Object.entries(SUPPORTED_CHAINS).map(([key, chain]) => {
                const isActive = chain.chainId === currentChain.chainId;
                const hasContracts = !!(chain.contracts?.nftContract && chain.contracts?.stakingContract);
                
                return (
                  <button
                    key={key}
                    onClick={() => handleChainSwitch(key)}
                    disabled={isSwitching}
                    className={`
                      w-full flex items-center gap-3 px-3 py-2.5
                      hover:bg-[#5d43ef]/10 transition-colors
                      ${isActive ? 'bg-[#5d43ef]/20' : ''}
                      ${isSwitching ? 'opacity-50 cursor-not-allowed' : ''}
                    `}
                  >
                    {getChainIcon(chain)}
                    
                    <div className="flex-1 text-left">
                      <div className="flex items-center gap-2">
                        <span className="text-sm text-white font-medium">
                          {chain.name}
                        </span>
                        {!hasContracts && (
                          <span className="text-xs text-yellow-500 bg-yellow-500/10 px-1.5 py-0.5 rounded">
                            No contracts
                          </span>
                        )}
                      </div>
                      <span className="text-xs text-gray-400">
                        {chain.nativeCurrency.symbol}
                      </span>
                    </div>
                    
                    {isActive && (
                      <Check className="w-4 h-4 text-[#5d43ef]" />
                    )}
                  </button>
                );
              })}
            </div>
            
            <div className="p-2 border-t border-[#2D3748]/40 bg-[#15132b]">
              <p className="text-xs text-gray-500 text-center">
                {Object.keys(SUPPORTED_CHAINS).length} testnets available
              </p>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default ChainSelector;
