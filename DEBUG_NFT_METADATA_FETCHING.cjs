// ============================================================================
// DEBUG: NFT Metadata Fetching for Onchain Staking
// ============================================================================
// This script tests metadata fetching for your specific NFT token IDs
// to see why rarity is not being detected properly

const { Web3 } = require('web3');

// Add fetch for Node.js (if not available)
if (typeof fetch === 'undefined') {
  global.fetch = require('node-fetch');
}

// IPFS Gateway configuration (inline to avoid import issues)
const IPFS_GATEWAYS = [
  'https://gateway.pinata.cloud/ipfs/',
  'https://ipfs.io/ipfs/',
  'https://cloudflare-ipfs.com/ipfs/',
  'https://gateway.ipfs.io/ipfs/'
];

function getIPFSUrl(hash) {
  return `${IPFS_GATEWAYS[0]}${hash}`;
}

// Your contract details
const CONTRACT_ADDRESS = "0x5Bb23220cC12585264fCd144C448eF222c8572A2";
const RPC_URL = "https://rpc-amoy.polygon.technology/";

// Test token IDs that are showing as "Common"
const TEST_TOKEN_IDS = ["55", "56", "57"];

// Contract ABI (minimal - just need tokenURI)
const MINIMAL_ABI = [
  {
    "inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
    "name": "tokenURI",
    "outputs": [{"internalType": "string", "name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  }
];

async function debugMetadataFetching() {
  console.log('🔍 DEBUG: Testing NFT Metadata Fetching');
  console.log('==========================================');
  
  try {
    // Initialize Web3
    const web3 = new Web3(RPC_URL);
    const contract = new web3.eth.Contract(MINIMAL_ABI, CONTRACT_ADDRESS);
    
    console.log(`📋 Contract: ${CONTRACT_ADDRESS}`);
    console.log(`🌐 RPC: ${RPC_URL}`);
    console.log(`🎯 Testing tokens: ${TEST_TOKEN_IDS.join(', ')}`);
    console.log('');
    
    for (const tokenId of TEST_TOKEN_IDS) {
      console.log(`\n🔍 TESTING TOKEN ID: ${tokenId}`);
      console.log('=====================================');
      
      try {
        // Step 1: Get tokenURI from contract
        console.log('📋 Step 1: Fetching tokenURI from contract...');
        const tokenURI = await contract.methods.tokenURI(tokenId).call();
        console.log(`✅ Token URI: ${tokenURI}`);
        
        if (!tokenURI || tokenURI === '' || tokenURI === 'undefined') {
          console.log('❌ No valid tokenURI found');
          continue;
        }
        
        // Step 2: Convert to accessible URL
        console.log('🔗 Step 2: Converting to accessible URL...');
        let metadataUrl;
        
        if (tokenURI.startsWith('ipfs://')) {
          const ipfsHash = tokenURI.replace('ipfs://', '');
          metadataUrl = getIPFSUrl(ipfsHash);
          console.log(`🔄 Converted IPFS URL: ${metadataUrl}`);
        } else if (tokenURI.startsWith('/api/ipfs/')) {
          // Handle custom /api/ipfs/QmHash format
          const ipfsHash = tokenURI.replace('/api/ipfs/', '');
          metadataUrl = getIPFSUrl(ipfsHash);
          console.log(`🔄 Converted custom API URL: ${metadataUrl}`);
        } else if (tokenURI.startsWith('http')) {
          metadataUrl = tokenURI;
          console.log(`✅ Direct HTTP URL: ${metadataUrl}`);
        } else {
          console.log(`❌ Unknown URI format: ${tokenURI}`);
          continue;
        }
        
        // Step 3: Fetch metadata
        console.log('📥 Step 3: Fetching metadata...');
        const response = await fetch(metadataUrl);
        
        if (!response.ok) {
          console.log(`❌ HTTP Error: ${response.status} ${response.statusText}`);
          continue;
        }
        
        const metadata = await response.json();
        console.log('✅ Metadata fetched successfully!');
        console.log('📋 Full metadata:', JSON.stringify(metadata, null, 2));
        
        // Step 4: Analyze rarity detection
        console.log('\n🎨 Step 4: Analyzing rarity detection...');
        
        let detectedRarity = null;
        const rarityMethods = [];
        
        // Method 1: Check attributes array
        if (metadata.attributes && Array.isArray(metadata.attributes)) {
          console.log(`🔍 Checking ${metadata.attributes.length} attributes...`);
          
          const rarityAttribute = metadata.attributes.find(attr => 
            attr.trait_type?.toLowerCase() === 'rarity' || 
            attr.trait_type?.toLowerCase() === 'tier' ||
            attr.trait_type?.toLowerCase() === 'level' ||
            attr.trait_type?.toLowerCase() === 'grade' ||
            attr.name?.toLowerCase() === 'rarity' ||
            attr.name?.toLowerCase() === 'tier'
          );
          
          if (rarityAttribute) {
            detectedRarity = rarityAttribute.value || rarityAttribute.trait_value;
            rarityMethods.push(`attributes.${rarityAttribute.trait_type || rarityAttribute.name}`);
            console.log(`✅ Found in attributes: ${detectedRarity} (${rarityAttribute.trait_type || rarityAttribute.name})`);
          } else {
            console.log('❌ No rarity found in attributes');
            console.log('📋 Available attributes:', metadata.attributes.map(attr => ({
              trait_type: attr.trait_type,
              name: attr.name,
              value: attr.value
            })));
          }
        } else {
          console.log('❌ No attributes array found');
        }
        
        // Method 2: Check direct properties
        if (!detectedRarity && metadata.rarity) {
          detectedRarity = metadata.rarity;
          rarityMethods.push('direct.rarity');
          console.log(`✅ Found as direct property: ${detectedRarity}`);
        }
        
        if (!detectedRarity && metadata.tier) {
          detectedRarity = metadata.tier;
          rarityMethods.push('direct.tier');
          console.log(`✅ Found as tier property: ${detectedRarity}`);
        }
        
        // Method 3: Check name and description
        if (!detectedRarity && metadata.name) {
          const nameRarity = extractRarityFromText(metadata.name);
          if (nameRarity) {
            detectedRarity = nameRarity;
            rarityMethods.push('name');
            console.log(`✅ Extracted from name: ${detectedRarity}`);
          }
        }
        
        if (!detectedRarity && metadata.description) {
          const descRarity = extractRarityFromText(metadata.description);
          if (descRarity) {
            detectedRarity = descRarity;
            rarityMethods.push('description');
            console.log(`✅ Extracted from description: ${detectedRarity}`);
          }
        }
        
        // Final result
        console.log('\n🎯 FINAL RESULT:');
        console.log(`Token ID: ${tokenId}`);
        console.log(`Detected Rarity: ${detectedRarity || 'NONE FOUND'}`);
        console.log(`Detection Methods: ${rarityMethods.join(', ') || 'None'}`);
        console.log(`Expected in DB: ${detectedRarity ? 'Should NOT be Common' : 'Will default to Common'}`);
        
        if (!detectedRarity) {
          console.log('\n💡 SUGGESTIONS:');
          console.log('1. Check if rarity is stored with different attribute names');
          console.log('2. Verify IPFS metadata structure matches expected format');
          console.log('3. Consider adding rarity as direct property in metadata');
          console.log('4. Check if metadata upload was successful');
        }
        
      } catch (tokenError) {
        console.error(`❌ Error testing token ${tokenId}:`, tokenError.message);
      }
    }
    
  } catch (error) {
    console.error('❌ Debug script failed:', error);
  }
}

// Helper function to extract rarity from text
function extractRarityFromText(text) {
  if (!text) return null;
  
  const lowerText = text.toLowerCase();
  const rarityKeywords = ['legendary', 'rare', 'common', 'platinum', 'gold', 'silver', 'epic', 'ultra rare', 'super rare'];
  
  for (const keyword of rarityKeywords) {
    if (lowerText.includes(keyword)) {
      console.log(`🔍 Found rarity keyword '${keyword}' in text: ${text}`);
      return keyword;
    }
  }
  
  return null;
}

// Run the debug script
debugMetadataFetching().then(() => {
  console.log('\n✅ Debug script completed');
}).catch(error => {
  console.error('❌ Debug script error:', error);
});
