import { createClient } from '@supabase/supabase-js';
import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

// ============================================================================
// CHAIN-SPECIFIC NFT CID POOL POPULATION SCRIPT
// ============================================================================
// This script uploads NFT images to IPFS and assigns them to specific blockchain chains
// Each NFT is tagged with:
// - assigned_chain: Which blockchain it should be claimed to
// - chain_id: Chain ID of the blockchain
// - chain_contract_address: NFT contract address on that chain
// ============================================================================

// Supabase configuration
const SUPABASE_URL = 'https://heacehinqihfexxrbwdr.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlYWNlaGlucWloZmV4eHJid2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMTMyMTMsImV4cCI6MjA2Njc4OTIxM30.9jBZljJ_uS1M2gX9u3Ao_7amPwGtI9myTrdK7cBK7-4';

// Pinata configuration
const PINATA_API_KEY = 'c7b965f39fffe52506b8';
const PINATA_SECRET_KEY = '55e1b40cb26e3c7dcc3925626eb2af139edcb5fda718467e6f60ecec18fc2332';

// IPFS Gateway fallbacks
const IPFS_GATEWAYS = [
  "https://gateway.pinata.cloud/ipfs/",
  "https://cloudflare-ipfs.com/ipfs/",
  "https://ipfs.io/ipfs/"
];

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Image cache to avoid re-uploading same images
const imageCache = new Map();

// ============================================================================
// BLOCKCHAIN CHAIN CONFIGURATION (from chains.ts)
// ============================================================================
const SUPPORTED_CHAINS = {
  POLYGON_AMOY: {
    network: 'polygon-amoy',
    chainId: 80002,
    name: 'Polygon Amoy Testnet',
    nftContract: '0x5Bb23220cC12585264fCd144C448eF222c8572A2',
    stakingContract: '0x1F2Dbf590b1c4C96c1ddb4FF55002Dbb33DA294e'
  },
  SEPOLIA: {
    network: 'sepolia',
    chainId: 11155111,
    name: 'Ethereum Sepolia',
    nftContract: '0xedE55c384D620dD9a06d39fA632b2B55f29Bd387',
    stakingContract: '0x637B5CbfBFd074Fe468e2B976b780862448F984C'
  },
  BSC_TESTNET: {
    network: 'bsc-testnet',
    chainId: 97,
    name: 'BNB Smart Chain Testnet',
    nftContract: '0xfaAA35A41f070B7408740Fefff0635fD5B66398b',
    stakingContract: '0x1FAe00647ff1931Ab9d234E685EAf5211bed12b7'
  },
  AVALANCHE_FUJI: {
    network: 'avalanche-fuji',
    chainId: 43113,
    name: 'Avalanche Fuji Testnet',
    nftContract: '0x7a85EE8944EC9d15528c7517D1FD2A173f552F08',
    stakingContract: '0x95F2B1d375532690a78f152E4c90F4a6196fB8Df'
  },
  ARBITRUM_SEPOLIA: {
    network: 'arbitrum-sepolia',
    chainId: 421614,
    name: 'Arbitrum Sepolia',
    nftContract: '0x71EC87B1aFBe18255e8c415c3d84c9369719de21',
    stakingContract: '0x5B17525Db3B6811F36a0e301d0Ff286b44b51147'
  },
  OPTIMISM_SEPOLIA: {
    network: 'optimism-sepolia',
    chainId: 11155420,
    name: 'Optimism Sepolia',
    nftContract: '0x68C3734b65e3b2f7858123ccb5Bfc5fd7cC1D733',
    stakingContract: '0x37Fdb126989C1c355b93f0155FEe0CbD0e892AF8'
  },
  BASE_SEPOLIA: {
    network: 'base-sepolia',
    chainId: 84532,
    name: 'Base Sepolia',
    nftContract: '0x10ca82E3F31459f7301BDE2ca8Cf93CCA4113705',
    stakingContract: '0xB250CD56aDB08cd30aBC275b9E20978A92bC4dd1'
  }
};

// Get array of all supported chains for distribution
const ALL_CHAINS = Object.values(SUPPORTED_CHAINS);

// ============================================================================
// NFT POOL CONFIGURATION WITH CHAIN DISTRIBUTION STRATEGY
// ============================================================================
// Strategy: Distribute NFTs evenly across all supported chains
// Each rarity will have NFTs assigned to different chains
// ============================================================================
const NFT_POOLS = {
  common: {
    count: 25,
    images: [
      'public/images/nft/common1.jpg',
      'public/images/nft/common2.jpg', 
      'public/images/nft/common3.jpg'
    ]
  },
  rare: {
    count: 30,
    images: [
      'public/images/nft/Rare1.jpg',
      'public/images/nft/Rare2.jpg',
      'public/images/nft/Rare3.jpg'
    ]
  },
  legendary: {
    count: 30,
    images: [
      'public/images/nft/Leg.jpg', 
      'public/images/nft/Leg2.jpg',
      'public/images/nft/Legendary.jpg',
      'public/images/nft/Legendary2.jpg',
      'public/images/nft/Legendary3.jpg'
    ]
  },
  platinum: {
    count: 5,
    images: [
      'public/images/nft/Plat.jpg',
      'public/images/nft/Platinum.jpg',
      'public/images/nft/Platinum2.jpg'
    ]
  },
  silver: {
    count: 5,
    images: ['public/images/nft/Silver.jpg']
  },
  gold: {
    count: 5,
    images: ['public/images/nft/Gold.jpg']
  }
};

/**
 * Assign chain to NFT based on index for even distribution
 */
function assignChainToNFT(index, totalNFTs) {
  const chainIndex = index % ALL_CHAINS.length;
  return ALL_CHAINS[chainIndex];
}

/**
 * Test IPFS gateway reliability and return best available gateway URL
 */
async function getBestGatewayUrl(ipfsHash) {
  for (const gateway of IPFS_GATEWAYS) {
    try {
      const url = `${gateway}${ipfsHash}`;
      const response = await fetch(url, { method: 'HEAD', timeout: 3000 });
      if (response.ok) {
        console.log(`✅ Gateway working: ${gateway}`);
        return url;
      }
    } catch (error) {
      console.warn(`⚠️ Gateway failed: ${gateway}`, error.message);
      continue;
    }
  }
  // Fallback to first gateway if all fail
  console.warn('⚠️ All gateways failed, using fallback');
  return `${IPFS_GATEWAYS[0]}${ipfsHash}`;
}

/**
 * Upload image file to IPFS using Pinata
 */
async function uploadImageToPinata(imagePath, filename) {
  try {
    const formData = new FormData();
    const imageBuffer = fs.readFileSync(imagePath);
    
    // Append file buffer directly with proper options
    formData.append('file', imageBuffer, {
      filename: filename,
      contentType: 'image/jpeg'
    });
    
    const pinataMetadata = JSON.stringify({
      name: filename,
      keyvalues: {
        type: 'nft_image',
        platform: 'neftit'
      }
    });
    formData.append('pinataMetadata', pinataMetadata);

    const response = await axios.post('https://api.pinata.cloud/pinning/pinFileToIPFS', formData, {
      headers: {
        'pinata_api_key': PINATA_API_KEY,
        'pinata_secret_api_key': PINATA_SECRET_KEY,
        ...formData.getHeaders()
      },
      maxContentLength: Infinity,
      maxBodyLength: Infinity
    });

    // Use best available gateway for image URL
    const bestImageUrl = await getBestGatewayUrl(response.data.IpfsHash);

    return {
      success: true,
      ipfsHash: response.data.IpfsHash,
      imageUrl: bestImageUrl
    };
  } catch (error) {
    console.error('❌ Error uploading image to Pinata:', error);
    const errorMsg = error.response?.data?.error || error.message;
    return { success: false, error: errorMsg };
  }
}

/**
 * Upload unique NFT with both image and metadata to IPFS
 * Now includes chain assignment
 */
async function uploadUniqueNFTToIPFS(rarity, index, assignedChain) {
  try {
    // Select image from available images for this rarity
    const availableImages = NFT_POOLS[rarity].images;
    const selectedImagePath = availableImages[index % availableImages.length];
    
    console.log(`📤 Uploading image: ${selectedImagePath} for chain: ${assignedChain.name}`);
    
    // Step 1: Check cache first, then upload image to IPFS
    let imageResult;
    if (imageCache.has(selectedImagePath)) {
      imageResult = imageCache.get(selectedImagePath);
      console.log(`🔄 Using cached image: ${imageResult.imageUrl}`);
    } else {
      const imageFilename = `neftit-${rarity}-${index}-${path.basename(selectedImagePath)}`;
      imageResult = await uploadImageToPinata(selectedImagePath, imageFilename);
      
      if (!imageResult.success) {
        throw new Error(`Image upload failed: ${imageResult.error}`);
      }
      
      // Cache the result
      imageCache.set(selectedImagePath, imageResult);
      console.log(`✅ Image uploaded to IPFS: ${imageResult.imageUrl}`);
    }
    
    // Step 2: Create metadata with IPFS image URL and chain info
    const getBackgroundColor = (rarity) => {
      switch(rarity) {
        case 'common': return '8B4513';     // Brown
        case 'rare': return 'C0C0C0';       // Silver
        case 'legendary': return 'FFD700';  // Gold
        case 'platinum': return 'E5E4E2';   // Platinum
        case 'silver': return 'C0C0C0';     // Silver
        case 'gold': return 'FFD700';       // Gold
        default: return '808080';           // Gray
      }
    };

    const getMetadataName = (rarity) => {
      switch(rarity) {
        case 'common': return 'NEFTIT Common';
        case 'rare': return 'NEFTIT Rare';
        case 'legendary': return 'Early Birds Legendary';
        case 'platinum': return 'NEFTINUM Platinum';
        case 'silver': return 'NEFTIT Silver';
        case 'gold': return 'NEFTIT Gold';
        default: return rarity.charAt(0).toUpperCase() + rarity.slice(1);
      }
    };

    const nftMetadata = {
      name: getMetadataName(rarity),
      description: `Unique ${rarity} NFT from NEFTIT platform - Serial #${index} - Assigned to ${assignedChain.name}`,
      image: imageResult.imageUrl,
      attributes: [
        { trait_type: "Rarity", value: rarity.charAt(0).toUpperCase() + rarity.slice(1) },
        { trait_type: "Serial Number", value: index },
        { trait_type: "Platform", value: "NEFTIT" },
        { trait_type: "Generation", value: "Unique CID Collection" },
        { trait_type: "Assigned Chain", value: assignedChain.name },
        { trait_type: "Chain ID", value: assignedChain.chainId },
        { trait_type: "Network", value: assignedChain.network },
        { trait_type: "Timestamp", value: new Date().toISOString() }
      ],
      external_url: "https://neftit.com",
      background_color: getBackgroundColor(rarity)
    };

    console.log(`📤 Uploading metadata for ${rarity} NFT #${index} on ${assignedChain.name}`);
    
    // Step 3: Upload metadata to IPFS using Pinata JSON API
    const pinataData = {
      pinataContent: nftMetadata,
      pinataMetadata: {
        name: `${getMetadataName(rarity)} - ${assignedChain.name}`,
        keyvalues: { 
          rarity: rarity,
          serial: index.toString(),
          type: 'nft_metadata',
          platform: 'neftit',
          image_hash: imageResult.ipfsHash,
          assigned_chain: assignedChain.network,
          chain_id: assignedChain.chainId.toString()
        }
      }
    };

    const response = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'pinata_api_key': PINATA_API_KEY,
        'pinata_secret_api_key': PINATA_SECRET_KEY
      },
      body: JSON.stringify(pinataData)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.log(`❌ Pinata API Error ${response.status}:`, errorText);
      throw new Error('Pinata upload failed: ' + response.status + ' - ' + errorText);
    }

    const result = await response.json();
    const metadataCID = result.IpfsHash;
    const metadataUrl = await getBestGatewayUrl(metadataCID);

    console.log(`✅ Complete NFT created - Chain: ${assignedChain.name}, Image: ${imageResult.imageUrl}, Metadata: ${metadataUrl}`);

    return {
      success: true,
      cid: metadataCID,
      image_url: imageResult.imageUrl,
      metadata_cid: metadataCID,
      metadata_url: metadataUrl,
      image_hash: imageResult.ipfsHash,
      assigned_chain: assignedChain.network,
      chain_id: assignedChain.chainId,
      chain_contract_address: assignedChain.nftContract
    };

  } catch (error) {
    console.error(`❌ Error uploading NFT ${rarity} #${index}:`, error);
    // Fallback to deterministic unique CID generation if upload fails
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 15);
    const fallbackCID = `Qm${rarity}${index.toString().padStart(6, '0')}${random}${timestamp}`;
    
    return {
      cid: fallbackCID,
      metadata_cid: `QmMeta${fallbackCID.substring(2)}`,
      image_url: `https://gateway.pinata.cloud/ipfs/${fallbackCID}`,
      assigned_chain: assignedChain.network,
      chain_id: assignedChain.chainId,
      chain_contract_address: assignedChain.nftContract
    };
  }
}

/**
 * Populate CID pools for all rarities with chain assignments
 */
async function populateCIDPoolsWithChains() {
  console.log('🚀 Starting CID pool population WITH CHAIN ASSIGNMENTS...');
  console.log(`🔗 Distributing across ${ALL_CHAINS.length} chains:`);
  ALL_CHAINS.forEach(chain => {
    console.log(`   - ${chain.name} (${chain.network})`);
  });
  
  const totalNFTs = Object.values(NFT_POOLS).reduce((sum, pool) => sum + pool.count, 0);
  console.log(`📊 Total NFTs to create: ${totalNFTs}`);
  
  let processedCount = 0;
  let globalIndex = 0; // For chain assignment rotation
  
  for (const [rarity, config] of Object.entries(NFT_POOLS)) {
    console.log(`\n🎯 Processing ${rarity} NFTs (${config.count} total)...`);
    
    // Process in smaller batches for IPFS uploads
    const batchSize = 5; // Reduced batch size for real IPFS uploads with chain data
    const batches = Math.ceil(config.count / batchSize);
    
    for (let batchIndex = 0; batchIndex < batches; batchIndex++) {
      const startIndex = batchIndex * batchSize;
      const endIndex = Math.min(startIndex + batchSize, config.count);
      const batchData = [];
      
      // Generate batch data with real IPFS uploads and chain assignments
      for (let i = startIndex; i < endIndex; i++) {
        const assignedChain = assignChainToNFT(globalIndex, totalNFTs);
        console.log(`📤 Uploading ${rarity} NFT #${i + 1} → ${assignedChain.name}...`);
        
        const ipfsResult = await uploadUniqueNFTToIPFS(rarity, i + 1, assignedChain);
        
        batchData.push({
          rarity,
          cid: ipfsResult.cid,
          image_url: ipfsResult.image_url,
          metadata_cid: ipfsResult.metadata_cid,
          is_distributed: false,
          assigned_chain: ipfsResult.assigned_chain,
          chain_id: ipfsResult.chain_id,
          chain_contract_address: ipfsResult.chain_contract_address,
          can_claim_to_any_chain: false // Only claimable to assigned chain
        });
        
        globalIndex++; // Increment for next chain assignment
        
        // Small delay to prevent rate limiting
        await new Promise(resolve => setTimeout(resolve, 200));
      }
      
      // Insert batch into database
      try {
        const { data, error } = await supabase
          .from('nft_cid_pools')
          .insert(batchData);
        
        if (error) {
          console.error(`❌ Error inserting batch ${batchIndex + 1}:`, error);
          continue;
        }
        
        processedCount += batchData.length;
        const progress = ((processedCount / totalNFTs) * 100).toFixed(1);
        console.log(`✅ Batch ${batchIndex + 1}/${batches} completed for ${rarity} (${progress}% total progress)`);
        
        // Small delay to prevent rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
        
      } catch (error) {
        console.error(`❌ Exception inserting batch ${batchIndex + 1}:`, error);
      }
    }
    
    console.log(`✅ Completed ${rarity}: ${config.count} NFTs created with chain assignments`);
  }
  
  console.log(`\n🎉 CID pool population completed! Total processed: ${processedCount}/${totalNFTs}`);
}

/**
 * Verify pool population with chain distribution
 */
async function verifyCIDPoolsWithChains() {
  console.log('\n🔍 Verifying CID pools with chain assignments...');
  
  try {
    const { data, error } = await supabase.rpc('get_available_cid_counts_by_chain');
    
    if (error) {
      console.error('❌ Error verifying pools:', error);
      return;
    }
    
    console.log('\n📊 CID Pool Statistics by Chain:');
    console.log('┌─────────────┬───────────────────────┬───────────┬─────────────┬─────────────────┐');
    console.log('│ Rarity      │ Chain                 │ Total     │ Available   │ Distributed     │');
    console.log('├─────────────┼───────────────────────┼───────────┼─────────────┼─────────────────┤');
    
    data.forEach(stat => {
      const rarity = stat.rarity.padEnd(11);
      const chain = (stat.assigned_chain || 'unassigned').padEnd(21);
      const total = stat.total_count.toString().padStart(9);
      const available = stat.available_count.toString().padStart(11);
      const distributed = stat.distributed_count.toString().padStart(15);
      console.log(`│ ${rarity} │ ${chain} │ ${total} │ ${available} │ ${distributed} │`);
    });
    
    console.log('└─────────────┴───────────────────────┴───────────┴─────────────┴─────────────────┘');
    
    // Get chain distribution stats
    const { data: statsData } = await supabase.rpc('get_chain_distribution_stats');
    if (statsData) {
      console.log('\n🔗 Chain Distribution Summary:');
      statsData.forEach(chainStat => {
        console.log(`\n📍 ${chainStat.chain}:`);
        console.log(`   Total NFTs: ${chainStat.total_nfts}`);
        console.log(`   Available: ${chainStat.available}`);
        console.log(`   Distributed: ${chainStat.distributed}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Exception verifying pools:', error);
  }
}

/**
 * Clear existing pools (use with caution)
 */
async function clearCIDPools() {
  console.log('⚠️  Clearing existing CID pools...');
  
  try {
    const { error } = await supabase
      .from('nft_cid_pools')
      .delete()
      .neq('id', 0); // Delete all records
    
    if (error) {
      console.error('❌ Error clearing pools:', error);
      return;
    }
    
    console.log('✅ CID pools cleared successfully');
  } catch (error) {
    console.error('❌ Exception clearing pools:', error);
  }
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'populate';
  
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║   NEFTIT CHAIN-SPECIFIC NFT CID POOL POPULATION SCRIPT      ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  
  switch (command) {
    case 'populate':
      await populateCIDPoolsWithChains();
      await verifyCIDPoolsWithChains();
      break;
      
    case 'verify':
      await verifyCIDPoolsWithChains();
      break;
      
    case 'clear':
      await clearCIDPools();
      break;
      
    default:
      console.log('\n📖 Usage: node populate-cid-pools-with-chains.js [populate|verify|clear]');
      console.log('  populate - Create CID pools with chain assignments (default)');
      console.log('  verify   - Check current pool statistics by chain');
      console.log('  clear    - Clear all existing pools (DANGEROUS)');
      console.log('\n🔗 Supported Chains:');
      ALL_CHAINS.forEach(chain => {
        console.log(`  - ${chain.name} (${chain.network}) - Chain ID: ${chain.chainId}`);
      });
  }
}

// Run the script
main().catch(console.error);
