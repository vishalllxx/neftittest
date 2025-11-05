// Type definitions for Solana wallet providers
interface Window {
  solana?: {
    isPhantom?: boolean;
    isConnected?: boolean;
    connect: () => Promise<{ publicKey: { toString: () => string } }>;
    disconnect: () => Promise<void>;
    signMessage: (message: Uint8Array, encoding?: string) => Promise<{ signature: Uint8Array; publicKey: { toString: () => string } }>;
    on: (event: string, callback: (...args: any[]) => void) => void;
    removeListener: (event: string, callback: (...args: any[]) => void) => void;
    publicKey?: { toString: () => string };
  };
}

