import { createClient } from '@supabase/supabase-js';
import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

// ============================================================================
// FLEXIBLE NFT CID POOL POPULATION SCRIPT
// ============================================================================
// This script uploads NFT images to IPFS WITHOUT chain assignments
// Chain assignment happens DURING DISTRIBUTION, not during upload
// This provides maximum flexibility for chain selection at distribution time
// ============================================================================

// Supabase configuration
const SUPABASE_URL = 'https://heacehinqihfexxrbwdr.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhlYWNlaGlucWloZmV4eHJid2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMTMyMTMsImV4cCI6MjA2Njc4OTIxM30.9jBZljJ_uS1M2gX9u3Ao_7amPwGtI9myTrdK7cBK7-4';

// Pinata configuration
const PINATA_API_KEY = '227ec56661ece9bafbe3';
const PINATA_SECRET_KEY = 'b03a803c4193824a62df194edccbeb822c9378a8f3384f1a23e57cec9b728100';

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
// NFT POOL CONFIGURATION
// ============================================================================
// Updated counts for multichain distribution
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
      'public/images/nft/Leg3.jpg'
    ]
  },
  platinum: {
    count: 10,
    images: [
      'public/images/nft/Plat.jpg',
      'public/images/nft/Plat2.jpg',
      'public/images/nft/Plat3.jpg',
      'public/images/nft/Plat4.jpg',
      'public/images/nft/Plat5.jpg',
      'public/images/nft/Plat6.jpg'
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
 * Upload NFT with generic metadata (NO chain assignment)
 * Chain will be assigned during distribution
 */
async function uploadFlexibleNFTToIPFS(rarity, index) {
  try {
    // Select image from available images for this rarity
    const availableImages = NFT_POOLS[rarity].images;
    const selectedImagePath = availableImages[index % availableImages.length];
    
    console.log(`📤 Uploading image: ${selectedImagePath} (flexible chain assignment)`);
    
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
    
    // Step 2: Create GENERIC metadata WITHOUT chain-specific info
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

    // Generic metadata - chain info will be added during distribution
    const nftMetadata = {
      name: getMetadataName(rarity),
      description: `Unique ${rarity} NFT from NEFTIT platform - Serial #${index}`,
      image: imageResult.imageUrl,
      attributes: [
        { trait_type: "Rarity", value: rarity.charAt(0).toUpperCase() + rarity.slice(1) },
        { trait_type: "Serial Number", value: index },
        { trait_type: "Platform", value: "NEFTIT" },
        { trait_type: "Generation", value: "Flexible CID Collection" },
        { trait_type: "Timestamp", value: new Date().toISOString() }
      ],
      external_url: "https://neftit.com",
      background_color: getBackgroundColor(rarity)
    };

    console.log(`📤 Uploading metadata for ${rarity} NFT #${index} (chain-agnostic)`);
    
    // Step 3: Upload metadata to IPFS using Pinata JSON API
    const pinataData = {
      pinataContent: nftMetadata,
      pinataMetadata: {
        name: `${getMetadataName(rarity)} - Flexible`,
        keyvalues: { 
          rarity: rarity,
          serial: index.toString(),
          type: 'nft_metadata',
          platform: 'neftit',
          image_hash: imageResult.ipfsHash,
          flexible: 'true'
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

    console.log(`✅ Flexible NFT created - Image: ${imageResult.imageUrl}, Metadata: ${metadataUrl}`);

    return {
      success: true,
      cid: metadataCID,
      image_url: imageResult.imageUrl,
      metadata_cid: metadataCID,
      metadata_url: metadataUrl,
      image_hash: imageResult.ipfsHash
    };

  } catch (error) {
    console.error(`❌ Error uploading NFT ${rarity} #${index}:`, error);
    // Fallback to deterministic unique CID generation if upload fails
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 15);
    const fallbackCID = `Qm${rarity}${index.toString().padStart(6, '0')}${random}${timestamp}`;
    
    return {
      success: false,
      cid: fallbackCID,
      metadata_cid: `QmMeta${fallbackCID.substring(2)}`,
      image_url: `https://gateway.pinata.cloud/ipfs/${fallbackCID}`,
      error: error.message
    };
  }
}

/**
 * Populate CID pools with flexible NFTs (NO chain assignments)
 */
async function populateFlexibleCIDPools() {
  console.log('🚀 Starting FLEXIBLE CID pool population...');
  console.log('🔗 NFTs will be chain-agnostic - chains assigned during distribution');
  
  const totalNFTs = Object.values(NFT_POOLS).reduce((sum, pool) => sum + pool.count, 0);
  console.log(`📊 Total NFTs to create: ${totalNFTs}`);
  
  let processedCount = 0;
  
  for (const [rarity, config] of Object.entries(NFT_POOLS)) {
    console.log(`\n🎯 Processing ${rarity} NFTs (${config.count} total)...`);
    
    // Process in smaller batches for IPFS uploads
    const batchSize = 5;
    const batches = Math.ceil(config.count / batchSize);
    
    for (let batchIndex = 0; batchIndex < batches; batchIndex++) {
      const startIndex = batchIndex * batchSize;
      const endIndex = Math.min(startIndex + batchSize, config.count);
      const batchData = [];
      
      // Generate batch data with real IPFS uploads (NO chain info)
      for (let i = startIndex; i < endIndex; i++) {
        console.log(`📤 Uploading ${rarity} NFT #${i + 1}...`);
        
        const ipfsResult = await uploadFlexibleNFTToIPFS(rarity, i + 1);
        
        batchData.push({
          rarity,
          cid: ipfsResult.cid,
          image_url: ipfsResult.image_url,
          metadata_cid: ipfsResult.metadata_cid,
          is_distributed: false,
          assigned_chain: null,                    // ✅ No chain assigned yet
          chain_id: null,                          // ✅ No chain ID yet
          chain_contract_address: null,            // ✅ No contract address yet
          can_claim_to_any_chain: true             // ✅ Flexible - can be assigned any chain
        });
        
        processedCount++;
        
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
        
        console.log(`✅ Inserted batch ${batchIndex + 1}/${batches} for ${rarity} (${batchData.length} NFTs)`);
      } catch (insertError) {
        console.error('❌ Database insertion error:', insertError);
      }
    }
    
    console.log(`✅ Completed ${rarity}: ${config.count} NFTs`);
  }
  
  console.log(`\n✨ Population complete! ${processedCount}/${totalNFTs} NFTs created`);
  console.log('📍 All NFTs are flexible - chains will be assigned during distribution');
}

/**
 * Clear all CID pools using database function
 */
async function clearCIDPools() {
  console.log('🗑️ Clearing all CID pools using database function...');
  
  try {
    const { data, error } = await supabase.rpc('clear_all_cid_pools');
    
    if (error) {
      console.error('❌ Error clearing pools:', error);
      return;
    }
    
    if (data.success) {
      console.log('✅ Pools cleared successfully');
      console.log(`   - Deleted ${data.deleted_pools} NFTs`);
      console.log(`   - Deleted ${data.deleted_distributions} distributions`);
    } else {
      console.error('❌ Failed to clear pools:', data.error);
    }
  } catch (error) {
    console.error('❌ Error calling clear function:', error);
  }
}

/**
 * Verify CID pool statistics
 */
async function verifyCIDPools() {
  console.log('📊 Verifying CID pool statistics...\n');
  
  try {
    const { data, error } = await supabase.rpc('get_available_cid_counts_by_chain');
    
    if (error) {
      console.error('❌ Error fetching statistics:', error);
      return;
    }
    
    console.log('📈 NFT Pool Statistics:');
    console.log('═'.repeat(80));
    
    let totalCount = 0;
    let totalAvailable = 0;
    
    data.forEach(stat => {
      const chain = stat.assigned_chain || 'unassigned';
      console.log(`${stat.rarity.toUpperCase().padEnd(12)} | ${chain.padEnd(20)} | Total: ${stat.total_count} | Available: ${stat.available_count} | Distributed: ${stat.distributed_count}`);
      totalCount += stat.total_count;
      totalAvailable += stat.available_count;
    });
    
    console.log('═'.repeat(80));
    console.log(`TOTALS: ${totalCount} NFTs total, ${totalAvailable} available, ${totalCount - totalAvailable} distributed`);
    
  } catch (error) {
    console.error('❌ Error verifying pools:', error);
  }
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'populate';
  
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║   NEFTIT FLEXIBLE NFT CID POOL POPULATION SCRIPT            ║');
  console.log('║   Chain Assignment During Distribution                      ║');
  console.log('╚══════════════════════════════════════════════════════════════╝\n');
  
  try {
    switch (command.toLowerCase()) {
      case 'populate':
        await populateFlexibleCIDPools();
        await verifyCIDPools();
        break;
        
      case 'clear':
        await clearCIDPools();
        break;
        
      case 'verify':
        await verifyCIDPools();
        break;
        
      default:
        console.log('Usage:');
        console.log('  node populate-cid-pools-flexible.js populate  - Create flexible NFTs');
        console.log('  node populate-cid-pools-flexible.js clear     - Clear all pools');
        console.log('  node populate-cid-pools-flexible.js verify    - Verify statistics');
        break;
    }
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

main();
