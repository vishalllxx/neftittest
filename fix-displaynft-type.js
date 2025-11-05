import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const filePath = path.join(__dirname, 'src/components/profile/MyNFTs.tsx');
let content = fs.readFileSync(filePath, 'utf8');

// Find the DisplayNFT type definition
const oldType = `  // Multichain properties
  blockchain?: string; // Network identifier (e.g., 'polygon-amoy', 'sepolia')
  chainId?: number; // Chain ID for the blockchain
  chainName?: string; // Human-readable chain name
  chainIconUrl?: string; // Chain logo URL
};`;

const newType = `  // Multichain properties
  blockchain?: string; // Network identifier (e.g., 'polygon-amoy', 'sepolia')
  chainId?: number; // Chain ID for the blockchain
  chainName?: string; // Human-readable chain name
  chainIconUrl?: string; // Chain logo URL
  // Chain-specific distribution properties
  assigned_chain?: string; // Blockchain this NFT is assigned to (from CID pool distribution)
  chain_contract_address?: string; // Contract address on assigned chain
  can_claim_to_any_chain?: boolean; // If true, can claim to any chain; if false, only to assigned_chain
  ipfs_cid?: string; // IPFS CID for chain validation
};`;

if (content.includes(oldType)) {
  content = content.replace(oldType, newType);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('✅ Successfully added assigned_chain fields to DisplayNFT type');
} else {
  console.log('❌ Could not find DisplayNFT type definition');
  process.exit(1);
}
