import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Link, useNavigate, useLocation } from "react-router-dom";
import {
  Menu,
  HomeIcon,
  ActivityIcon,
  Sparkles,
  FlameIcon,
  Zap,
  HelpCircle,
  User,
  LogOut,
  Gift,
} from "lucide-react";
import { useIsMobile } from "@/hooks/use-mobile";
import { ProfileButton } from "@/components/profile/ProfileButton";
import { ProfileBox } from "@/components/profile/ProfileBox";
import { ChainSelector } from "@/components/ChainSelector";
import {
  NavigationItems,
  NavigationItemType,
} from "@/components/navigation/NavigationItems";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { useState } from "react";
import classNames from "classnames";
import { motion } from "framer-motion";
import { useWallet } from "@/components/wallet/WalletProvider";
import WalletConnectionModal from "@/components/wallet/WalletConnectionModal";
import { useAuthState } from "@/hooks/useAuthState";
import { useUserBalance } from "@/contexts/UserBalanceContext";

import { toast } from "sonner";
import { DailyClaim } from "@/pages/DailyClaim";

interface MainNavProps {
  // Optional setter for an external wallet modal state
  setExternalWalletModalOpen?: (isOpen: boolean) => void;
  children?: React.ReactNode;
}

export function MainNav({
  setExternalWalletModalOpen,
  children,
}: MainNavProps) {
  const isMobile = useIsMobile();
  const [isWalletModalOpen, setIsWalletModalOpen] = useState(false);

  const location = useLocation();
  
  // ✨ NEW: Use global balance context instead of local state
  const { balance: userBalance, isLoading: isLoadingBalance } = useUserBalance();

  const { isConnected, isAuthenticated, disconnect } = useWallet();
  const { walletAddress } = useAuthState();

  // ✅ REMOVED: All balance loading logic (now handled by global context)
  // - No more useEffect for loading balance
  // - No more event listeners
  // - No more subscription management
  // - Balance is automatically synced across all pages!

  const handleLoginClick = () => {
    // If external modal state setter is provided, use it
    if (setExternalWalletModalOpen) {
      setExternalWalletModalOpen(true);
    } else {
      setIsWalletModalOpen(true);
    }
  };

  const handleLogout = () => {
    try {
      // Disconnect wallet
      disconnect();

      // Clear all localStorage items
      localStorage.removeItem("walletAddress");
      localStorage.removeItem("isAuthenticated");
      localStorage.removeItem("walletType");
      localStorage.removeItem("walletBalance");
      localStorage.removeItem("stakedAmount");
      localStorage.removeItem("walletConnectConnected");
      localStorage.removeItem("lastAuthPayload");
      localStorage.removeItem("lastAuthError");

      // Clear sessionStorage items
      sessionStorage.removeItem("walletAddress");
      sessionStorage.removeItem("username");
      sessionStorage.removeItem("avatar");

      // Show success toast
      toast.success("Logged out successfully");

      // Dispatch event for other components that might need to know about logout
      window.dispatchEvent(new CustomEvent('user-logout'));
    } catch (error) {
      console.error("Error during logout:", error);
      toast.error("Error logging out. Please try again.");
    }
  };

  const mainNavItems: NavigationItemType[] = [
    {
      name: "Home",
      icon: <HomeIcon className="h-4 w-4" />,
      path: "/home",
      description: "Go to home page",
    },
    {
      name: "Activity",
      icon: <ActivityIcon className="h-4 w-4" />,
      path: "/activity",
      description: "View your activity",
    },
    {
      name: "Discover",
      icon: <Sparkles className="h-4 w-4" />,
      path: "/discover",
      description: "Explore NFTs",
    },
    {
      name: "Burn",
      icon: <FlameIcon className="h-4 w-4" />,
      path: "/burn",
      description: "Burn NFTs",
    },
    {
      name: "Stake",
      icon: <Zap className="h-4 w-4" />,
      path: "/staking",
      description: "Stake your NFTs",
    },
    {
      name: "Daily Claim",
      icon: <Gift className="h-4 w-4" />,
      path: "/daily-claim",
      description: "Claim daily rewards",
    },
    {
      name: "How It Works",
      icon: <HelpCircle className="h-4 w-4" />,
      path: "/how-it-works",
      description: "Learn how it works",
    },
  ];

  const isDiscoverActive = location.pathname === "/discover";
  const isBurnActive = location.pathname === "/burn";
  const isStakeActive = location.pathname === "/staking";

  return (
    <div>
      <motion.nav
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className={classNames(
          "fixed top-0 w-full z-50 bg-[#0B0A14]/10 backdrop-blur-xl ",
          "transition-colors duration-200"
        )}
      >
        <div className="container h-[72px] flex items-center justify-between">
          <div className="flex items-center gap-3 md:gap-8 mr-2 md:mr-0">
            <Link
              to="/"
              className="text-xl sm:text-2xl font-light tracking-wider text-white hover:text-white/90 transition-colors"
            >
              <img src="/images/logo.png" alt="NEFTIT Logo" className="object-contain md:object-fill h-4 md:h-5" />
            </Link>

            <div className="flex items-center gap-4 lg:gap-6">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Link
                    to="/discover"
                    className="relative text-muted-foreground hover:text-foreground transition-colors group"
                  >
                    <span>Discover</span>
                    <span
                      className={
                        isDiscoverActive
                          ? "absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-purple-500 to-blue-500"
                          : "absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-purple-500 to-blue-500 group-hover:w-full transition-all duration-300"
                      }
                    ></span>
                  </Link>
                </TooltipTrigger>
                <TooltipContent className="bg-card/90 backdrop-blur-xl border-white/10">
                  Explore NFT collections
                </TooltipContent>
              </Tooltip>

              {!isMobile && isAuthenticated && (
                <>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Link
                        to="/burn"
                        className="relative text-muted-foreground hover:text-foreground transition-colors group"
                      >
                        <span>Burn</span>
                        <span
                          className={
                            isBurnActive
                              ? "absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-orange-500 to-red-500"
                              : "absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-orange-500 to-red-500 group-hover:w-full transition-all duration-300"
                          }
                        ></span>
                      </Link>
                    </TooltipTrigger>
                    <TooltipContent className="bg-card/90 backdrop-blur-xl border-white/10">
                      Burn & upgrade your NFTs
                    </TooltipContent>
                  </Tooltip>

                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Link
                        to="/staking"
                        className="relative text-muted-foreground hover:text-foreground transition-colors group"
                      >
                        <span>Stake</span>
                        <span
                          className={
                            isStakeActive
                              ? "absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-green-500 to-emerald-500"
                              : "absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-green-500 to-emerald-500 group-hover:w-full transition-all duration-300"
                          }
                        ></span>
                      </Link>
                    </TooltipTrigger>
                    <TooltipContent className="bg-card/90 backdrop-blur-xl border-white/10">
                      Stake NFTs & tokens to earn rewards
                    </TooltipContent>
                  </Tooltip>

                  <DailyClaim />

                </>
              )}
            </div>
          </div>

          <div className="flex items-center gap-2 md:gap-4">
            {/* Chain Selector - only show when connected */}
            {(isAuthenticated) && (
              <ChainSelector  className="" />
            )}

            {/* Combined NEFT and XP counter - only show when connected */}
            {(isAuthenticated) && (
              <motion.div
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                whileHover={{ scale: 1.03 }}
                transition={{ type: "spring", stiffness: 400, damping: 10 }}
                className="hidden sm:flex items-center divide-x divide-[#1b1930] rounded-lg bg-gradient-to-r from-[#1b1930] to-[#1b1930] backdrop-blur-sm "
              >
                <div className="px-4 py-1.5 flex items-center gap-1.5">
                  {isLoadingBalance ? (
                    <div className="animate-pulse bg-white/20 h-4 w-16 rounded"></div>
                  ) : (
                    <span className="text-sm font-medium bg-gradient-to-r from-white to-white/80 bg-clip-text text-transparent">
                      {userBalance?.total_neft_claimed ?
                        (userBalance.total_neft_claimed % 1 === 0 ?
                          userBalance.total_neft_claimed.toFixed(0) :
                          userBalance.total_neft_claimed.toFixed(2)
                        ) : '0'} NEFT
                    </span>
                  )}
                </div>              
              </motion.div>
            )}

            {/* Login button - always visible on landing page (/), otherwise only for unauthenticated users */}
            {!isAuthenticated && (
              <Button
                onClick={handleLoginClick}
                className=" bg-gradient-to-l from-[#5d43ef]/100 via-[#5d43ef]/80 to-[rgb(166,170,216)] hover:from-[#5d43ef] hover:to-[#0b0a14] text-white border-[#5d43ef] backdrop-blur-sm transition-all duration-300 hover:scale-105 ml-4 h-7"
              >
                Login
              </Button>
            )}

            {isMobile && (isAuthenticated) ? (
              <Sheet>
                <SheetTrigger asChild>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="text-white hover:bg-white/5 transition-all duration-200"
                  >
                    <Menu className="h-5 w-5" />
                  </Button>
                </SheetTrigger>
                <SheetContent
                  side="right"
                  className="w-80 sidebar-bg backdrop-blur-xl p-0 overflow-y-auto border-0"
                >
                  {(isAuthenticated) && (
                    <ProfileBox />
                  )}
                  <div className="border-t border-[#5d43ef]/20"></div>
                  <div className="py-0">
                    <NavigationItems items={mainNavItems} />

                    {/* Logout is now handled in NavigationItems component */}
                  </div>
                </SheetContent>
              </Sheet>
            ) : (
              <>
                {isAuthenticated ? (
                  <Sheet>
                    <SheetTrigger asChild>
                      <div className="animate-scale-in">
                        <motion.div
                          whileHover={{ scale: 1.05 }}
                          transition={{
                            type: "spring",
                            stiffness: 400,
                            damping: 10,
                          }}
                        >
                          <ProfileButton />
                        </motion.div>
                      </div>
                    </SheetTrigger>
                    <SheetContent
                      side="right"
                      className="w-[300px] sidebar-bg backdrop-blur-xl p-0 overflow-y-auto border-0"
                    >
                      <ProfileBox />
                      <div className="border-t border-[#5d43ef]/20"></div>
                      <div className="py-0">
                        <NavigationItems items={mainNavItems} />

                        {/* Logout is now handled in NavigationItems component */}
                      </div>
                    </SheetContent>
                  </Sheet>
                ) : null}
              </>
            )}
          </div>
        </div>
      </motion.nav>
      <div className="pt-[72px]">{children}</div>

      {/* Wallet Connection Modal */}
      <WalletConnectionModal
        isOpen={isWalletModalOpen}
        onClose={() => setIsWalletModalOpen(false)}
      />
    </div>
  );
}
