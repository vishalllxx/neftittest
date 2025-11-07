// Check which burn-related tables exist
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔍 CHECKING BURN TABLES...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTables() {
  const testWallet = 'social:google:100335175710056438027';
  
  // Check burn_transactions table
  console.log('1️⃣ Checking burn_transactions table...');
  const { data: burnTx, error: burnTxErr } = await supabase
    .from('burn_transactions')
    .select('*')
    .eq('wallet_address', testWallet)
    .limit(5);
  
  if (burnTxErr) {
    console.log(`   ❌ Error: ${burnTxErr.message}\n`);
  } else {
    console.log(`   ✅ Table exists! Found ${burnTx.length} burn records\n`);
    if (burnTx.length > 0) {
      console.log('   Sample record:');
      console.log(`   - ID: ${burnTx[0].id}`);
      console.log(`   - Burned NFT IDs: ${burnTx[0].burned_nft_ids}`);
      console.log(`   - Result Rarity: ${burnTx[0].result_rarity}`);
      console.log(`   - Created: ${burnTx[0].created_at}\n`);
    }
  }
  
  // Check nft_burns table
  console.log('2️⃣ Checking nft_burns table...');
  const { data: nftBurns, error: nftBurnsErr } = await supabase
    .from('nft_burns')
    .select('*')
    .eq('wallet_address', testWallet)
    .limit(5);
  
  if (nftBurnsErr) {
    console.log(`   ❌ Table doesn't exist: ${nftBurnsErr.message}\n`);
  } else {
    console.log(`   ✅ Table exists! Found ${nftBurns.length} burn records\n`);
  }
  
  console.log('═══════════════════════════════════════════════════');
  console.log('\n📋 CONCLUSION:\n');
  
  if (burnTxErr && nftBurnsErr) {
    console.log('❌ NO BURN TABLES EXIST!');
    console.log('   The burn achievement system cannot track burns.\n');
  } else if (!burnTxErr && burnTx.length === 0) {
    console.log('✅ burn_transactions table exists (used by your burn system)');
    console.log('❌ nft_burns table does NOT exist (used by achievement system)');
    console.log('\n🔧 FIX NEEDED:');
    console.log('   The achievement function uses nft_burns table,');
    console.log('   but your app uses burn_transactions table.');
    console.log('\n   Solution: Update achievement function to use burn_transactions!\n');
  } else if (!burnTxErr && burnTx.length > 0) {
    console.log(`✅ burn_transactions table exists with ${burnTx.length} records!`);
    console.log('❌ nft_burns table does NOT exist');
    console.log('\n🔧 FIX NEEDED:');
    console.log('   Achievement function needs to read from burn_transactions,');
    console.log('   not nft_burns table!\n');
  }
}

checkTables().catch(console.error);
