import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  ReactNode,
  useCallback,
  useRef,
} from "react";
import { toast } from "sonner";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import {
  useAddress,
  useConnectionStatus,
  useDisconnect,
  useChain,
  useBalance,
  ConnectWallet,
  useConnect,
  metamaskWallet,
  coinbaseWallet,
  phantomWallet,
  trustWallet,
  rainbowWallet,
  WalletOptions
} from "@thirdweb-dev/react";
import { authenticateUser, getUserProfile, handlePostAuth } from "@/lib/thirdwebAuth";
import { processSocialLogin, getMockOAuthData } from "@/api/socialAuth";
import { useWallet as useSuiWallet } from '@suiet/wallet-kit';
import { useUpsertUser } from '@/hooks/useUpsertUser';
import { supabase } from '@/lib/supabase';
import { performNonceBasedAuth } from '@/api/nonceAuth';


type WalletType = "evm" | "solana" | "sui" | "social";

interface WalletContextType {
  address: string | null;
  isConnected: boolean;
  connect: (type?: WalletType | string) => Promise<void>;
  disconnect: () => void;
  isAuthenticated: boolean;
  walletType: WalletType | null;
  balance: number;
  stakedAmount: number;
  updateBalance: (newBalance: number) => void;
  updateStakedAmount: (newStakedAmount: number) => void;
}

const WalletContext = createContext<WalletContextType & { connecting: boolean }>({
  address: null,
  isConnected: false,
  connect: async () => { },
  disconnect: () => { },
  isAuthenticated: false,
  walletType: null,
  balance: 0,
  stakedAmount: 0,
  updateBalance: () => { },
  updateStakedAmount: () => { },
  connecting: false,
});

export const useWallet = () => useContext(WalletContext);

interface WalletProviderProps {
  children: ReactNode;
}

export const WalletProvider: React.FC<WalletProviderProps> = ({ children }) => {
  // ThirdWeb hooks
  const thirdwebAddress = useAddress();
  const thirdwebConnectionStatus = useConnectionStatus();
  const thirdwebDisconnect = useDisconnect();
  const thirdwebConnect = useConnect();
  const currentChain = useChain();
  const { data: walletBalance } = useBalance();

  // Local state
  const [address, setAddress] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [walletType, setWalletType] = useState<WalletType | null>(null);
  const [balance, setBalance] = useState<number>(0);
  const [stakedAmount, setStakedAmount] = useState<number>(0);
  const [connecting, setConnecting] = useState<boolean>(false);
  const [connectionAttempt, setConnectionAttempt] = useState<number>(0);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [walletConnectionStatus, setWalletConnectionStatus] = useState<{
    status: string;
    message: string;
    error?: string;
  }>({ status: "disconnected", message: "Not connected" });

  // Track if this is the initial load to prevent auto-connection
  const [isInitialLoad, setIsInitialLoad] = useState(true);
  const [hasAuthenticated, setHasAuthenticated] = useState(false);
  const { address: suiAddress, connected: suiConnected } = useSuiWallet();
  const { upsertUser } = useUpsertUser();
  
  // Store the actual MetaMask provider when multiple wallets are installed
  const [actualMetaMaskProvider, setActualMetaMaskProvider] = useState<any>(null);
  
  // Sign-in popup states (for signature request phase)
  const [showSignInModal, setShowSignInModal] = useState(false);
  const [signingWallet, setSigningWallet] = useState<string | null>(null);
  const [showRetryButton, setShowRetryButton] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  
  // Wallet configuration for sign-in popups (same design as WalletConnectionModal)
  const walletConfig = {
    MetaMask: {
      icon: '/icons/metamask-icon.png',
      name: 'MetaMask',
      signingText: 'Sign In with MetaMask',
      instructionText: 'Unlock MetaMask if needed, then sign to authenticate ✨'
    },
    evm: {
      icon: '/icons/metamask-icon.png',
      name: 'MetaMask',
      signingText: 'Sign In with MetaMask',
      instructionText: 'Unlock MetaMask if needed, then sign to authenticate ✨'
    },
    WalletConnect: {
      icon: '/icons/WalletConnect-icon.png',
      name: 'WalletConnect',
      signingText: 'Sign In with WalletConnect',
      instructionText: 'Sign the message in your wallet 🔑'
    },
    Phantom: {
      icon: '/icons/phantom-wallet.png',
      name: 'Phantom',
      signingText: 'Sign In with Phantom',
      instructionText: 'Sign the message to authenticate ✨'
    },
    solana: {
      icon: '/icons/phantom-wallet.png',
      name: 'Phantom',
      signingText: 'Sign In with Phantom',
      instructionText: 'Sign the message to authenticate ✨'
    },
    Sui: {
      icon: '/icons/sui-sui-logo.png',
      name: 'Sui',
      signingText: 'Sign In with Sui Wallet',
      instructionText: 'Sign the message to authenticate 🌊'
    },
    sui: {
      icon: '/icons/sui-sui-logo.png',
      name: 'Sui',
      signingText: 'Sign In with Sui Wallet',
      instructionText: 'Sign the message to authenticate 🌊'
    }
  };

  // Update local state when ThirdWeb state changes
  useEffect(() => {
    const savedAddress = localStorage.getItem("walletAddress") || localStorage.getItem("userAddress");
    const savedAuthStatus = localStorage.getItem("isAuthenticated");
    const savedWalletType = localStorage.getItem("walletType") as WalletType;
    const savedBalance = localStorage.getItem("walletBalance");
    const savedStakedAmount = localStorage.getItem("stakedAmount");
    const socialProvider = localStorage.getItem("socialProvider");

    // PRIORITY 1: Check for Sui wallet connection (non-ThirdWeb)
    if (savedWalletType === 'sui' && suiConnected && suiAddress) {
      console.log("Sui wallet connected:", suiAddress);
      setAddress(suiAddress);
      setIsConnected(true);
      setWalletType('sui');
      
      if (savedAuthStatus === "true") {
        setIsAuthenticated(true);
      }
    }
    // PRIORITY 2: ThirdWeb wallets (MetaMask, WalletConnect, etc.)
    else if (thirdwebAddress && savedWalletType !== 'sui') {
      console.log("ThirdWeb address updated:", thirdwebAddress);
      
      // 🔥 CRITICAL FIX: If we have actualMetaMaskProvider, get address from it directly
      // This prevents using Phantom's address when both wallets are installed
      if (actualMetaMaskProvider && savedWalletType === 'evm') {
        actualMetaMaskProvider.request({ method: 'eth_accounts' })
          .then((accounts: string[]) => {
            if (accounts && accounts.length > 0) {
              const metamaskAddress = accounts[0];
              console.log('✅ Using MetaMask provider address:', metamaskAddress);
              console.log('⚠️ ThirdWeb gave us:', thirdwebAddress);
              setAddress(metamaskAddress); // Use MetaMask's address, not ThirdWeb's
            } else {
              setAddress(thirdwebAddress); // Fallback to ThirdWeb address
            }
          })
          .catch(() => {
            setAddress(thirdwebAddress); // Fallback on error
          });
      } else {
        setAddress(thirdwebAddress);
      }
      
      setIsConnected(true);

      // DO NOT set localStorage here - this will be set AFTER signature verification
      // in the authenticateWithBackend function via processWalletLogin
      // Premature localStorage setting causes the app to think user is authenticated
      // before signature verification completes

      // If we were connecting and now we have an address, we're done with WALLET connection
      // But DON'T set connecting=false yet - authentication still needs to happen
      // The authenticateWithBackend function will set connecting=false after auth completes
      if (connecting && connectionAttempt > 0) {
        // Only show toast if this is NOT an EVM wallet (EVM wallets need signature first)
        if (savedWalletType !== 'evm' && connectionAttempt === 1) {
          toast.success("Wallet connected successfully!");
        }
      }
    } 
    // PRIORITY 3: Restore from localStorage (for page refreshes)
    else if (savedAddress && !thirdwebAddress) {
      setAddress(savedAddress);
      setIsConnected(true);
      setWalletType(savedWalletType);

      // If this is a social login, set authenticated state
      if (savedWalletType === 'social' && socialProvider) {
        setIsAuthenticated(true);
        console.log(`Restored social login session for provider: ${socialProvider}`);
      }
      if (savedAuthStatus === "true") {
        setIsAuthenticated(true);
      }

      if (savedBalance) {
        setBalance(Number(savedBalance));
      }

      if (savedStakedAmount) {
        setStakedAmount(Number(savedStakedAmount));
      }
    } else if (thirdwebConnectionStatus === "disconnected" && !suiConnected) {
      // Only clear address if we're explicitly disconnected (not just on initial load)
      if (!isInitialLoad) {
        setAddress(null);
        setIsConnected(false);
        setIsAuthenticated(false);
      }
    }
  }, [thirdwebAddress, thirdwebConnectionStatus, connecting, connectionAttempt, isInitialLoad, suiAddress, suiConnected]);



  //Set initial load to false after component mounts
  // useEffect(() => {
  //   setIsInitialLoad(false);
  // }, []);

  // // Clean up on unmount
  // useEffect(() => {
  //   return () => {
  //     // Clean up WalletConnect event listeners
  //     if (cleanupWalletConnect.current) {
  //       cleanupWalletConnect.current();
  //     }
  //   };
  // }, []);




  // Update balance when wallet balance changes
  // useEffect(() => {
  //   if (walletBalance && isConnected) {
  //     const formattedBalance = parseFloat(walletBalance.displayValue);
  //     setBalance(formattedBalance);
  //     localStorage.setItem("walletBalance", formattedBalance.toString());
  //   }
  // }, [walletBalance, isConnected]);

  // const getUserProfile = async (address: string) => {
  //   try {
  //     // Call the real getUserProfile from thirdwebAuth
  //     const userData = await import("../../lib/thirdwebAuth").then(
  //       (module) => module.getUserProfile(address)
  //     );
  //     return userData;
  //   } catch (error) {
  //     console.error("Failed to get user profile:", error);
  //     return null;
  //   }
  // };



  const connectWallet = useCallback(
    async (type: WalletType | string = "evm"): Promise<void> => {
      try {
        // Prevent multiple connection attempts
        if (connecting) {
          console.log("Already connecting, please wait...");
          return;
        }

        setConnecting(true);
        setConnectionAttempt(prev => prev + 1);

        // Clear any existing connection data first to prevent stale state
        localStorage.removeItem("walletAddress");
        localStorage.removeItem("userAddress");
        localStorage.removeItem("isAuthenticated");
        localStorage.removeItem("lastAuthenticatedWallet");
        
        // Reset authentication state
        setIsAuthenticated(false);
        setHasAuthenticated(false);

        console.log(`Connecting wallet with type: ${type}`);

        // Map provider name to wallet type
        let actualWalletType: WalletType = "evm";
        if (type === "Phantom" || type === "solana") {
          actualWalletType = "solana";
        } else if (type === "sui") {
          actualWalletType = "sui";
        }

        // Check if the wallet is installed before attempting to connect
        if (type === "MetaMask") {
          // Proper MetaMask detection (handle case where Phantom overrides window.ethereum)
          let metamaskProvider = null;
          const originalProvider = window.ethereum; // Save original provider
          
          console.log('🔍 Detecting MetaMask...');
          console.log('window.ethereum:', {
            isMetaMask: window.ethereum?.isMetaMask,
            isPhantom: window.ethereum?.isPhantom,
            hasProviders: !!window.ethereum?.providers,
            providersCount: window.ethereum?.providers?.length
          });
          
          // Check if there are multiple providers (MetaMask + Phantom both installed)
          if (window.ethereum?.providers) {
            console.log('📋 Multiple providers detected:', window.ethereum.providers.map((p: any) => ({
              isMetaMask: p.isMetaMask,
              isPhantom: p.isPhantom
            })));
            // Find the actual MetaMask provider
            metamaskProvider = window.ethereum.providers.find((p: any) => p.isMetaMask && !p.isPhantom);
            console.log('✅ Found MetaMask provider:', !!metamaskProvider);
          } else if (window.ethereum?.isMetaMask && !window.ethereum?.isPhantom) {
            // Only MetaMask is installed
            metamaskProvider = window.ethereum;
            console.log('✅ Using single MetaMask provider');
          }
          
          if (!metamaskProvider) {
            console.log('❌ MetaMask provider not found');
            toast.error("MetaMask is not installed. Please install it to continue.");
            window.open("https://metamask.io/download/", "_blank");
            setConnecting(false);
            return;
          }
          
          console.log('🔌 Connecting to MetaMask via ThirdWeb...');
          
          // CRITICAL FIX: Temporarily override window.ethereum to point to MetaMask
          // This ensures ThirdWeb connects to MetaMask, not Phantom
          const needsOverride = window.ethereum?.providers && window.ethereum !== metamaskProvider;
          if (needsOverride) {
            console.log('🔄 Temporarily overriding window.ethereum with MetaMask provider');
            (window as any).ethereum = metamaskProvider;
            // Store MetaMask provider for later use in authentication
            setActualMetaMaskProvider(metamaskProvider);
          }
          
          try {
            await thirdwebConnect(metamaskWallet());
            console.log('✅ ThirdWeb connection complete, setting wallet type...');
            setWalletType("evm");
            localStorage.setItem("walletType", "evm");
            console.log('🎯 MetaMask connection complete, address should be set by useEffect');
            // DON'T call setConnecting(false) here - let authenticateWithBackend do it
          } finally {
            // DON'T restore window.ethereum yet - keep MetaMask as active provider
            console.log('💾 Keeping MetaMask provider active for authentication');
          }
        } else if (type === "Phantom") {
          // ⚠️ CRITICAL: Phantom ONLY for Solana in NEFTIT
          // For EVM chains, users MUST use MetaMask
          console.log('🟣 Connecting to Phantom for SOLANA ONLY (not EVM)');
          
          // Check if Phantom Solana wallet is installed
          const provider = window.solana;
          if (!provider || !provider.isPhantom) {
            toast.error("Phantom wallet is not installed. Please install it to continue.");
            window.open("https://phantom.app/", "_blank");
            setConnecting(false);
            return;
          }
          try {
            setWalletType("solana");
            localStorage.setItem("walletType", "solana");
            console.log('🔌 Connecting to Phantom Solana provider...');
            
            // Connect to Phantom SOLANA provider (window.solana, NOT window.ethereum)
            const resp = await provider.connect();
            const solAddress = resp.publicKey?.toString();
            if (solAddress) {
              const walletAddress = `${solAddress}`;
              setAddress(walletAddress);
              setIsConnected(true);
              
              console.log('✅ Phantom connected successfully for Solana:', solAddress);
              
              // Dispatch event to close main login modal
              console.log('📡 Dispatching wallet-connected event for Phantom');
              window.dispatchEvent(new CustomEvent('wallet-connected', { 
                detail: { provider: 'Phantom', address: walletAddress, chain: 'solana' } 
              }));
              
              // Small delay to let modal close before showing sign-in popup
              await new Promise(resolve => setTimeout(resolve, 400));
              
              // authenticateWithBackend will handle setting isAuthenticated and redirecting
              await authenticateWithBackend(walletAddress, "solana");
              // No need to redirect here - authenticateWithBackend handles it
            }
          } catch (error) {
            console.error("Phantom wallet error:", error);
            toast.error("Failed to connect with Phantom. Please try again.");
            setConnecting(false);
            return;
          }
        } else if (type === "sui") {
          // Check if we're in Edit Profile linking mode - if so, skip main authentication
          const isLinkingMode = localStorage.getItem('edit_profile_linking_mode') === 'true';
          const linkingWalletType = localStorage.getItem('linking_wallet_type');

          if (isLinkingMode && linkingWalletType === 'sui') {
            console.log('🔄 Sui wallet connection in Edit Profile linking mode - skipping main authentication');
            setConnecting(false);
            return;
          }

          // Only support Phantom as a Solana wallet (not EVM)
          const provider = window.sui;
          if (!provider || !provider.isSui) {
            toast.error("Sui wallet is not installed. Please install it to continue.");
            window.open("https://suiet.app/install", "_blank");
            setConnecting(false);
            return;
          }
          try {
            setWalletType("sui");
            localStorage.setItem("WalletType", "sui");
            // Connect to Sui wallet and authenticate
            const resp = await provider.connect();
            const suiAddress = resp.publicKey?.toString();
            if (suiAddress) {
              const walletAddress = `${suiAddress}`;
              setAddress(walletAddress);
              setIsConnected(true);
              
              // Dispatch event to close main login modal
              console.log('📡 Dispatching wallet-connected event for Sui');
              window.dispatchEvent(new CustomEvent('wallet-connected', { 
                detail: { provider: 'Sui', address: walletAddress } 
              }));
              
              // Small delay to let modal close before showing sign-in popup
              await new Promise(resolve => setTimeout(resolve, 400));
              
              // authenticateWithBackend will handle setting isAuthenticated and redirecting
              await authenticateWithBackend(walletAddress, "sui");
              // No need to redirect here - authenticateWithBackend handles it
            }
          } catch (error) {
            console.error("Sui wallet error:", error);
            toast.error("Failed to connect with Sui. Please try again.");
            setConnecting(false);
            return;
          }
        } else if (type === "Google" || type === "Discord" || type === "X") {
          try {
            // Set loading state
            setConnecting(true);

            // Log the social login attempt
            console.log(`Initiating ${type} social login...`);

            // Convert X to twitter for provider name (OAuth system expects 'twitter')
            const provider = type === "X" ? "twitter" : type.toLowerCase();

            // Store the provider we're using for the callback page
            localStorage.setItem('oauth_provider', provider);

            // Import Supabase client
            const { supabase } = await import("@/lib/supabase");

            // Dispatch event to close main login modal and show connecting popup
            console.log(`📡 Dispatching wallet-connected event for ${type} social login`);
            window.dispatchEvent(new CustomEvent('wallet-connected', { 
              detail: { provider: type, chain: 'social' } 
            }));

            // Small delay to let connecting modal show
            await new Promise(resolve => setTimeout(resolve, 300));

            // Use Supabase's OAuth - this will open a popup window
            // This opens a real OAuth authentication window from the provider
            // When complete, it will redirect to our /auth/callback route
            const { data, error } = await supabase.auth.signInWithOAuth({
              provider: provider as any, // Type as any to avoid TypeScript errors
              options: {
                redirectTo: `${window.location.origin}/auth/callback`
              }
            });

            if (error) {
              throw new Error(`OAuth error: ${error.message}`);
            }

            if (!data) {
              throw new Error('No data returned from OAuth provider');
            }

            // The OAuth flow will redirect to the callback URL
            // The redirect will happen automatically, no need to do anything else here
            console.log("OAuth initiated successfully, waiting for redirect...");

            // Since the OAuth flow will redirect the page, we don't need to
            // manually handle the success case here
          } catch (error) {
            console.error(`${type} login error:`, error);
            toast.error(`${type} login failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
            setConnecting(false);
          }
        } else {
          // ✅ FIXED: Default to MetaMask for "evm", "MetaMask" or unknown wallet types
          // This handles all EVM chains (Polygon, Ethereum, BSC, Avalanche, etc.)
          console.log('🦊 Connecting to MetaMask for EVM chains...');
          
          // Check if MetaMask is installed
          if (!window.ethereum) {
            toast.error("MetaMask is not installed. Please install it to continue.");
            window.open("https://metamask.io/download/", "_blank");
            setConnecting(false);
            return;
          }
          
          // 🔥 CRITICAL: When both MetaMask and Phantom are installed,
          // window.ethereum might be Phantom (if Phantom was installed last)
          // We need to detect and use the REAL MetaMask provider
          let metamaskProvider = window.ethereum;
          
          // Check if window.ethereum.providers exists (multiple wallets installed)
          if (window.ethereum.providers && Array.isArray(window.ethereum.providers)) {
            console.log('🔍 Multiple EVM wallets detected, searching for MetaMask...');
            // Find MetaMask provider
            const foundMetaMask = window.ethereum.providers.find(
              (provider: any) => provider.isMetaMask && !provider.isPhantom
            );
            if (foundMetaMask) {
              metamaskProvider = foundMetaMask;
              console.log('✅ Found real MetaMask provider');
              // Store for later use in authentication
              setActualMetaMaskProvider(foundMetaMask);
            } else {
              console.warn('⚠️ MetaMask not found in providers array, using default');
            }
          } else if (window.ethereum.isMetaMask && !window.ethereum.isPhantom) {
            // Single wallet or MetaMask detected
            console.log('✅ MetaMask is the primary provider');
            setActualMetaMaskProvider(window.ethereum);
          } else if (window.ethereum.isPhantom) {
            // Phantom is masquerading as primary provider - search for MetaMask
            console.warn('⚠️ Phantom detected as primary provider, searching for MetaMask...');
            if (window.ethereum.providers) {
              const foundMetaMask = window.ethereum.providers.find(
                (p: any) => p.isMetaMask && !p.isPhantom
              );
              if (foundMetaMask) {
                metamaskProvider = foundMetaMask;
                console.log('✅ Found MetaMask in providers');
                setActualMetaMaskProvider(foundMetaMask);
              }
            }
          }
          
          // Connect using ThirdWeb with the correct MetaMask provider
          await thirdwebConnect(metamaskWallet());
          setWalletType("evm");
          localStorage.setItem("walletType", "evm");
          
          console.log('✅ MetaMask connection initiated for EVM chains');
        }

        // After successful wallet connection and address retrieval:
        if (thirdwebAddress) {
          const { supabase } = await import('@/lib/supabase');
          const { data: existingUser } = await supabase
            .from('users')
            .select('*')
            .eq('wallet_address', thirdwebAddress)
            .single();

          if (!existingUser) {
            // New user: upsert with display_name
            await upsertUser({
              wallet_address: thirdwebAddress,
              display_name: `User_${thirdwebAddress.slice(0, 6)}`,
              wallet_type: actualWalletType,
              provider: type,
            });
          } else {
            // Existing user: upsert only fields you want to update (do NOT send display_name)
            await upsertUser({
              wallet_address: thirdwebAddress,
              wallet_type: actualWalletType,
              provider: type,
              // Do NOT send display_name here!
            });
          }
        }

        // The address will be set by the useEffect hook when thirdwebAddress updates
        // This avoids the "no address found" issue

        // Wait a bit for the connection to complete
        await new Promise(resolve => setTimeout(resolve, 500));

        // Check if we have an address now
        if (!thirdwebAddress) {
          // Connection in progress, no need to show error yet
          // The useEffect will handle setting the address when it becomes available
          console.log("Waiting for address from wallet...");
        } else {
          // We already have an address, let's finish the process
          // FIXED: Removed duplicate call - useEffect will handle authentication to avoid double signature requests
          // await authenticateWithBackend(thirdwebAddress, type);
        }
      } catch (error) {
        console.error("Connection error:", error);
        setConnecting(false);

        // Show appropriate error message
        if (error instanceof Error) {
          if (error.message.includes("User rejected")) {
            toast.error(`Connection cancelled. You rejected the ${type} connection request.`);
          } else if (error.message.includes("Already processing")) {
            toast.error(`Already processing a ${type} connection. Please wait.`);
          } else {
            toast.error(`Failed to connect wallet: ${error.message}`);
          }
        } else {
          toast.error(`Failed to connect wallet. Please try again.`);
        }

        // Clear connection state
        clearConnectionState();
      }
    },
    [thirdwebConnect, thirdwebAddress, connecting, connectionAttempt, upsertUser]
  );

  // Helper function to authenticate with backend using unified system with nonce verification
  const authenticateWithBackend = async (walletAddress: string, providerType: WalletType | string) => {
    try {
      console.log(`🔐 Authenticating wallet ${walletAddress} with provider ${providerType} using nonce-based system`);

      // Determine wallet type name
      let walletTypeName = typeof providerType === "string" ? providerType : providerType;
      if (walletTypeName === "evm") {
        walletTypeName = "metamask"; // Default EVM to MetaMask
      }

      // For EVM wallets (MetaMask, WalletConnect), perform nonce-based authentication
      let authData: any = {
        provider_type: providerType
      };

      if (providerType === "MetaMask" || providerType === "evm" || providerType === "WalletConnect") {
        try {
          console.log('🎲 Starting nonce-based authentication for EVM wallet...');
          console.log('⏸️ WAITING for user to sign message in wallet...');
          
          // Show sign-in popup modal
          setSigningWallet(providerType as string);
          setShowSignInModal(true);
          setShowRetryButton(false);
          
          // Retry button will be shown only if the user cancels or an error occurs

          // Use the stored MetaMask provider if available (when both MetaMask and Phantom are installed)
          // Otherwise use window.ethereum (when only MetaMask is installed)
          const providerToUse = actualMetaMaskProvider || window.ethereum;
          console.log('🔑 Using provider for signature:', actualMetaMaskProvider ? 'Stored MetaMask' : 'window.ethereum');

          // Perform nonce-based authentication (generates nonce, requests signature, verifies)
          // This will now automatically trigger MetaMask unlock if wallet is locked
          const { nonce, message, signature } = await performNonceBasedAuth(
            walletAddress,
            providerToUse
          );

          // Signature obtained successfully

          authData = {
            ...authData,
            nonce,
            message,
            signature,
            timestamp: new Date().toISOString()
          };

          console.log('✅ Signature obtained and verified successfully');
          console.log('📤 Sending authentication request to backend...');
          
          // Hide sign-in popup after successful signature
          setShowSignInModal(false);
          setSigningWallet(null);
          setShowRetryButton(false);
        } catch (error: any) {
          // Keep the sign-in modal open and reveal Retry button
          setShowSignInModal(true);
          setShowRetryButton(true);
          
          // Handle signature rejection (user clicked Cancel on wallet)
          if (error.message?.includes('rejected') || error.message?.includes('User denied') || error.message?.includes('User rejected')) {
            console.log('❌ User rejected signature request');
            toast.info('Signature was cancelled. You can retry the request.', { duration: 5000 });
            setConnecting(false);
            return;
          }
          
          // Handle MetaMask locked/busy errors
          if (error.message?.includes('busy') || error.code === -32002) {
            console.log('⚠️ MetaMask is busy');
            toast.error('MetaMask is busy. Please check for pending requests and then retry.');
            setConnecting(false);
            return;
          }
          
          // Handle timeout errors
          if (error.message?.includes('timed out') || error.message?.includes('timeout')) {
            console.log('⏱️ Signature request timed out');
            toast.error('Signature request timed out. Bring the wallet to front or click Retry.', { duration: 8000 });
            setConnecting(false);
            return;
          }
          
          console.error('❌ Nonce-based auth failed:', error);
          toast.error(`Authentication failed: ${error.message || 'Please try again'}`, { duration: 6000 });
          setConnecting(false);
          return;
        }
      } else if (providerType === "solana" || providerType === "Phantom") {
        // Phantom/Solana nonce-based authentication
        try {
          console.log('🎲 Starting Phantom/Solana nonce-based authentication...');
          console.log('⏸️ WAITING for user to sign message in Phantom...');
          
          // Show sign-in popup modal
          setSigningWallet('Phantom');
          setShowSignInModal(true);
          toast.info('Please sign the message in Phantom to authenticate...', { duration: 5000 });

          const provider = window.solana;
          if (!provider) {
            throw new Error('Phantom wallet not found');
          }

          // Perform nonce-based authentication (generates nonce, requests signature, verifies)
          const { performSolanaNonceAuth } = await import('@/api/nonceAuth');
          const { nonce, message, signature } = await performSolanaNonceAuth(
            walletAddress,
            provider
          );

          authData = {
            ...authData,
            nonce,
            message,
            signature,
            timestamp: new Date().toISOString()
          };

          console.log('✅ Phantom signature obtained and nonce verified successfully');
          console.log('📤 Sending authentication request to backend...');
          
          // Hide sign-in popup after successful signature
          setShowSignInModal(false);
          setSigningWallet(null);
        } catch (error: any) {
          // Keep sign-in modal open and reveal Retry button
          setShowSignInModal(true);
          setShowRetryButton(true);
          
          // Handle signature rejection
          if (error.message?.includes('rejected') || error.message?.includes('User denied') || error.code === 4001) {
            console.log('❌ User rejected Phantom signature request');
            toast.info('Signature was cancelled. You can retry the request.', { duration: 5000 });
            setConnecting(false);
            return;
          }
          
          console.error('❌ Phantom nonce-based auth failed:', error);
          toast.error('Failed to authenticate with Phantom. Please try again.');
          setConnecting(false);
          return;
        }
      }

      // Use unified wallet authentication system
      const { processWalletLogin } = await import('@/api/walletAuth');
      const authResult = await processWalletLogin(walletAddress, walletTypeName, authData);

      if (!authResult.success) {
        throw new Error(authResult.error || 'Wallet authentication failed');
      }

      // 🔥 CRITICAL FIX: Use the primary wallet address from unified system
      // This ensures that when logging in with a linked wallet (e.g., Phantom),
      // we save the primary wallet address (e.g., MetaMask) to localStorage
      const primaryWalletAddress = authResult.userData?.wallet_address || walletAddress;
      const isPrimaryWallet = primaryWalletAddress.toLowerCase() === walletAddress.toLowerCase();
      
      console.log('🔍 Wallet login result:', {
        loginWallet: walletAddress,
        primaryWallet: primaryWalletAddress,
        isPrimaryWallet,
        walletType: walletTypeName
      });

           // Show success message
           if (authResult.isNewUser) {
            console.log('🎉 New user created successfully');
            toast.success(`Welcome! Your ${walletTypeName} wallet account has been created.`);
          } else {
            if (isPrimaryWallet) {
              console.log('👋 Existing user logged in with primary wallet');
              toast.success(`Welcome back! Logged in with ${walletTypeName}.`);
            } else {
              console.log('👋 Existing user logged in with linked wallet');
              toast.success(`Welcome back! Logged in with linked ${walletTypeName}. Showing your unified account.`);
            }
          }
    

      // Set localStorage to persist authentication state
      // 🔥 ALWAYS save the PRIMARY wallet address, not the linked wallet
      console.log('💾 Saving to localStorage:', {
        primaryWalletAddress,
        loginWalletAddress: walletAddress,
        walletType: walletTypeName,
        providerType
      });
      
      localStorage.setItem("walletAddress", primaryWalletAddress);
      localStorage.setItem("userAddress", primaryWalletAddress); // Also set userAddress for compatibility
      localStorage.setItem("isAuthenticated", "true");
      localStorage.setItem("walletType", walletTypeName);
      localStorage.setItem("lastLogin", new Date().toISOString());
      localStorage.setItem("lastAuthenticatedWallet", walletAddress);
      
      // Verify localStorage was set correctly
      const verifyAddress = localStorage.getItem("walletAddress");
      console.log('✅ Verified localStorage walletAddress:', verifyAddress);
      
      if (verifyAddress !== primaryWalletAddress) {
        console.error('❌ LocalStorage verification FAILED! Expected primary wallet:', primaryWalletAddress, 'Got:', verifyAddress);
      } else {
        console.log('✅ LocalStorage correctly saved primary wallet address');
      }

      // Clean up: Reset stored provider reference and restore window.ethereum
      if (actualMetaMaskProvider) {
        console.log('🧹 Clearing stored MetaMask provider and restoring window.ethereum');
        // Restore original window.ethereum (with providers array) before redirect
        // This prevents Phantom from auto-connecting after page reload
        setActualMetaMaskProvider(null);
      }
      
      // Set connecting to false now that authentication is complete
      setConnecting(false);

      // Small delay to ensure localStorage is committed before redirect
      await new Promise(resolve => setTimeout(resolve, 50));

      // Redirect to /discover
      console.log('✅ Redirecting to /discover now...');
      window.location.href = "/discover";
    
        } catch (error: any) {
      console.error("Wallet authentication error:", error);
      toast.error(`Failed to authenticate wallet: ${error.message}`);

      // Set authentication failed status
      setWalletConnectionStatus({
        status: "error",
        message: "Authentication failed",
        error: error.message
      });

      // Reset connection state
      setConnecting(false);
      setIsConnected(false);
      setAddress(null);
      
      // Clear stored MetaMask provider on error
      if (actualMetaMaskProvider) {
        setActualMetaMaskProvider(null);
      }

      throw error;
    }
  };

  // Social login wrapper function
  const socialLoginWrapper = async (provider: string) => {
    try {
      // Import and call the unified social auth system
      const { processSocialLogin } = await import('@/api/socialAuth');
      const result = await processSocialLogin(provider, {});

      if (result.success) {
        setIsAuthenticated(true);
        setAddress(result.walletAddress);
        setIsConnected(true);
      }

      return result;
    } catch (error) {
      console.error('Social login wrapper error:', error);
      throw error;
    }
  };

  // Helper function to retry signature request manually
  const handleRetrySignature = async () => {
    console.log('🔄 Manual retry signature request triggered');
    setRetryCount(prev => prev + 1);
    setShowRetryButton(false);
    
    try {
      // Get current wallet address
      const currentAddress = address || thirdwebAddress;
      if (!currentAddress) {
        toast.error('No wallet address found. Please reconnect your wallet.');
        setShowSignInModal(false);
        setSigningWallet(null);
        setConnecting(false);
        return;
      }

      // Show guidance toast
      toast.info('Opening MetaMask... Please check for signature request', { duration: 5000 });
      
      // Use the stored MetaMask provider or window.ethereum
      const providerToUse = actualMetaMaskProvider || window.ethereum;
      
      if (!providerToUse) {
        toast.error('MetaMask provider not found. Please refresh the page.');
        setShowSignInModal(false);
        setSigningWallet(null);
        setConnecting(false);
        return;
      }

      // Try to directly open MetaMask with a simple request first
      // This can trigger the MetaMask popup to come to foreground
      try {
        await providerToUse.request({ 
          method: 'wallet_requestPermissions',
          params: [{ eth_accounts: {} }]
        });
      } catch (permError) {
        console.log('Permission request failed or rejected, continuing with signature...');
      }

      // Small delay to let MetaMask popup appear
      await new Promise(resolve => setTimeout(resolve, 500));

      // Retry the authentication
      await authenticateWithBackend(currentAddress, walletType || "evm");
      
    } catch (error: any) {
      console.error('❌ Retry failed:', error);
      toast.error(`Retry failed: ${error.message || 'Please try again'}`, { duration: 5000 });
      setShowSignInModal(false);
      setSigningWallet(null);
      setConnecting(false);
    }
  };

  // Helper function to clear connection state
  const clearConnectionState = () => {
    localStorage.removeItem("walletAddress");
    localStorage.removeItem("userAddress");
    localStorage.removeItem("isAuthenticated");
    localStorage.removeItem("walletType");
    localStorage.removeItem("walletBalance");
    localStorage.removeItem("stakedAmount");
    localStorage.removeItem("socialProvider");
    localStorage.removeItem("oauth_provider");
    localStorage.removeItem("supabase_access_token");
    localStorage.removeItem("supabase_refresh_token");
    localStorage.removeItem("__TW__/coordinatorStorage/lastConnectedWallet");

    setAddress(null);
    setIsConnected(false);
    setIsAuthenticated(false);
    setWalletType(null);
    setBalance(0);
    setStakedAmount(0);
  };

  const disconnect = useCallback(() => {
    console.log("Disconnecting wallet...");

    // First, clear all component state to prevent any race conditions
    setAddress(null);
    setIsConnected(false);
    setIsAuthenticated(false);
    setWalletType(null);
    setBalance(0);
    setStakedAmount(0);

    // Keep track of all cleanup operations that need to complete
    const cleanupPromises = [];

    // Attempt to disconnect from ThirdWeb first
    try {
      if (thirdwebConnectionStatus === 'connected') {
        thirdwebDisconnect();
      }
    } catch (error) {
      console.error("Error during ThirdWeb disconnect:", error);
    }

    // For MetaMask, attempt to clear connection state
    if (window.ethereum && window.ethereum.selectedAddress) {
      try {
        // For MetaMask, we can't force disconnect from their side
        // We can only clear our local connection state
        console.log("Clearing MetaMask connection state locally");
      } catch (error) {
        console.error("Error during MetaMask disconnect:", error);
      }
    }

    // For Supabase social login, we need to sign out - use await here directly
    const socialProvider = localStorage.getItem("socialProvider");
    if (socialProvider) {
      console.log(`Signing out social login (${socialProvider})`);

      try {
        // Add Supabase signout to our cleanup operations
        const supabaseSignout = import("@/lib/supabase").then(async (module) => {
          // Use supabase directly from the export
          const { supabase } = module;
          return supabase.auth.signOut().then(() => {
            console.log('Successfully signed out from Supabase');
          }).catch(e => {
            console.error('Error signing out from Supabase:', e);
          });
        });

        cleanupPromises.push(supabaseSignout);
      } catch (signOutError) {
        console.error("Error during social login sign out:", signOutError);
      }
    }

    // Clear ALL localStorage data to ensure complete reset
    console.log("Clearing all localStorage data");
    Object.keys(localStorage).forEach(key => {
      localStorage.removeItem(key);
    });

    // Clear ALL sessionStorage data
    console.log("Clearing all sessionStorage data");
    Object.keys(sessionStorage).forEach(key => {
      sessionStorage.removeItem(key);
    });

    // Dispatch an event that other components can listen for
    window.dispatchEvent(new CustomEvent('wallet-disconnected'));

    toast.success("Wallet disconnected");

    // Wait for all cleanup operations to complete before redirecting
    Promise.all(cleanupPromises).then(() => {
      console.log("All cleanup operations completed, redirecting to home page");
      // Force a hard redirect to the home page to reset all state
      window.location.replace("/");
    }).catch(error => {
      console.error("Error during cleanup:", error);
      // Still redirect even if cleanup fails
      window.location.replace("/");
    });
  }, [thirdwebDisconnect, thirdwebConnectionStatus]);

  const updateBalance = (newBalance: number) => {
    setBalance(newBalance);
    localStorage.setItem("walletBalance", newBalance.toString());
  };

  const updateStakedAmount = (newStakedAmount: number) => {
    setStakedAmount(newStakedAmount);
    localStorage.setItem("stakedAmount", newStakedAmount.toString());
  };

  // Social login integration (Google, Discord, etc.)
  const socialLogin = async (provider: string) => {
    try {
      // Set loading state
      setIsLoading(true);
      setWalletConnectionStatus({
        status: "connecting",
        message: `Connecting to ${provider}...`
      });

      console.log(`Initiating ${provider} login...`);

      // Import supabase client
      const { supabase } = await import("@/lib/supabase");

      // Start the Supabase OAuth flow - this navigates away from the current page
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: provider as any, // Type as any to avoid TypeScript errors
        options: {
          redirectTo: `${window.location.origin}/auth/callback`
        }
      });

      if (error) {
        console.error("Social login error:", error);
        setWalletConnectionStatus({
          status: "error",
          message: `Failed to connect to ${provider}.`,
          error: error.message
        });
        toast.error(`Could not connect to ${provider}. ${error.message || "Unknown error"}`);
        return;
      }

      if (!data || !data.url) {
        console.error("No redirect URL returned from Supabase");
        setWalletConnectionStatus({
          status: "error",
          message: `Failed to connect to ${provider}.`,
          error: "No redirect URL received"
        });
        toast.error(`Could not connect to ${provider}. No redirect URL received.`);
        return;
      }

      console.log(`${provider} OAuth URL received, redirecting...`);

      // The browser will now navigate to the OAuth URL from Supabase
      // When the authentication is complete, the provider will redirect back to our callback URL
      window.location.href = data.url;

    } catch (error: any) {
      console.error(`${provider} login error:`, error);
      setWalletConnectionStatus({
        status: "error",
        message: `Failed to connect to ${provider}.`,
        error: error.message || "Unknown error"
      });

      toast.error(`Could not connect to ${provider}. ${error.message || "Unknown error"}`);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    // Handle authentication for wallet connections
    const lastAuthenticatedWallet = localStorage.getItem("lastAuthenticatedWallet");
    
    // FIXED: Only auto-authenticate if user explicitly initiated connection via connect button
    // This prevents auto-triggering signature request on page load
    if (
      isConnected &&
      thirdwebAddress &&
      !hasAuthenticated &&
      thirdwebAddress !== lastAuthenticatedWallet &&
      connecting && // Changed: Only authenticate if user is actively connecting
      connectionAttempt > 0 // Changed: Ensure user initiated the connection
    ) {
      console.log('🔄 useEffect triggering authentication for:', thirdwebAddress);
      setHasAuthenticated(true);
      // Fixed: Wrapped in async IIFE to ensure redirect completes
      (async () => {
        await authenticateWithBackend(thirdwebAddress, walletType || "evm");
      })();
    }
    
    // Reset authentication flag on disconnect
    if (!isConnected) {
      setHasAuthenticated(false);
    }
  }, [isConnected, thirdwebAddress, walletType, connecting, connectionAttempt]);

  // Add Phantom reconnect and pending redirect logic
  // useEffect(() => {
  //   const savedWalletType = localStorage.getItem("walletType");

  //   if (savedWalletType === "solana" && !isConnected) {
  //     const provider = window.solana;

  //     if (provider && provider.isPhantom) {
  //       provider.connect({ onlyIfTrusted: true })
  //         .then((resp) => {
  //           const solAddress = resp.publicKey?.toString();
  //           if (solAddress) {
  //             const walletAddress = `${solAddress}|solana`;

  //             setAddress(walletAddress);
  //             setIsConnected(true);
  //             setWalletType("solana");
  //             setIsAuthenticated(true);

  //             console.log("[Phantom] Reconnected on load:", walletAddress);

  //             // Handle pending redirect
  //             const pendingRedirect = localStorage.getItem("pendingRedirect");
  //             if (pendingRedirect && window.location.pathname !== pendingRedirect) {
  //               localStorage.removeItem("pendingRedirect");
  //               window.location.replace(pendingRedirect);
  //             }
  //           }
  //         })
  //         .catch((err) => {
  //           console.warn("[Phantom] Reconnect failed:", err);
  //         });
  //     }
  //   }
  // }, []);

  return (
    <WalletContext.Provider value={{
      address,
      isConnected,
      connect: connectWallet,
      disconnect,
      isAuthenticated,
      walletType,
      balance,
      stakedAmount,
      updateBalance,
      updateStakedAmount,
      connecting, // <-- expose connecting
    }}>
      {children}
      
      {/* Sign-In Popup Modal (for signature request phase) */}
      {signingWallet && walletConfig[signingWallet as keyof typeof walletConfig] && (
        <Dialog open={showSignInModal} onOpenChange={(open) => {
          if (!open) {
            setShowSignInModal(false);
            setSigningWallet(null);
            // User cancelled signature request
            setConnecting(false);
            setIsAuthenticated(false);
            setHasAuthenticated(false);
          }
        }}>
          <DialogContent className="w-[320px] bg-[#121021] backdrop-blur-xl border border-[#5d43ef]/20 rounded-xl text-white">
            <div className="flex flex-col items-center justify-center py-8 gap-6">
              {/* Wallet Icon */}
              <div className="relative">
                <img 
                  src={walletConfig[signingWallet as keyof typeof walletConfig].icon} 
                  alt={walletConfig[signingWallet as keyof typeof walletConfig].name} 
                  width={64} 
                  height={64} 
                  className="rounded-full"
                  onError={(e) => {
                    const target = e.target as HTMLImageElement;
                    target.onerror = null;
                    target.style.display = 'none';
                  }}
                />
                {/* Loading spinner overlay */}
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="w-16 h-16 border-[3px] border-white/20 border-t-[3px] border-t-white rounded-full animate-spin" />
                </div>
              </div>
              
              {/* Sign-In Text */}
              <div className="text-center space-y-2">
                <h3 className="text-lg font-semibold text-white">
                  {walletConfig[signingWallet as keyof typeof walletConfig].signingText}
                </h3>
                <p className="text-sm text-gray-400">
                  {walletConfig[signingWallet as keyof typeof walletConfig].instructionText}
                </p>
              </div>
              
              {/* Retry Button */}
              {showRetryButton && (
                <button
                  onClick={handleRetrySignature}
                  className="mt-4 px-6 py-3 bg-[#5d43ef] hover:bg-[#6d53ff] text-white font-medium rounded-lg transition-all duration-200 flex items-center gap-2 group"
                >
                  <svg 
                    className="w-4 h-4 group-hover:rotate-180 transition-transform duration-500" 
                    fill="none" 
                    stroke="currentColor" 
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  <span>Retry Signature Request</span>
                  {retryCount > 0 && <span className="text-xs opacity-70">(Attempt {retryCount + 1})</span>}
                </button>
              )}
              
              {/* Cancel Button */}
              <button
                onClick={() => {
                  setShowSignInModal(false);
                  setSigningWallet(null);
                  setShowRetryButton(false);
                  setConnecting(false);
                  setIsAuthenticated(false);
                  setHasAuthenticated(false);
                  toast.info('Authentication cancelled');
                }}
                className="mt-2 text-sm text-gray-400 hover:text-white transition-colors"
              >
                Cancel
              </button>
            </div>
          </DialogContent>
        </Dialog>
      )}
    </WalletContext.Provider>
  );
};

export default WalletProvider;
