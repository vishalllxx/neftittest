// Analyze NFT Burn Achievements System
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔥 ANALYZING NFT BURN ACHIEVEMENTS SYSTEM...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function analyzeSystem() {
  const testWallet = 'social:google:100335175710056438027';
  
  console.log(`Testing with wallet: ${testWallet}\n`);
  console.log('═══════════════════════════════════════════════════════════\n');
  
  // 1. Check nft_burns table structure and data
  console.log('1️⃣ NFT_BURNS TABLE DATA:');
  const { data: burnsData, error: burnsErr } = await supabase
    .from('nft_burns')
    .select('*')
    .eq('wallet_address', testWallet)
    .order('created_at', { ascending: false });
  
  if (burnsErr) {
    console.log(`   ❌ Error: ${burnsErr.message}`);
  } else {
    console.log(`   Total burn records: ${burnsData.length}`);
    if (burnsData.length > 0) {
      console.log('\n   Recent burns:');
      burnsData.slice(0, 5).forEach((burn, i) => {
        console.log(`   ${i + 1}. Burned at: ${burn.created_at}`);
        console.log(`      Token ID: ${burn.token_id || 'N/A'}`);
        console.log(`      Transaction: ${burn.transaction_hash || 'N/A'}`);
      });
    } else {
      console.log('   ℹ️  No burn records found for this wallet');
    }
  }
  
  console.log('\n═══════════════════════════════════════════════════════════\n');
  
  // 2. Check achievement definitions
  console.log('2️⃣ BURN ACHIEVEMENT DEFINITIONS:');
  const { data: achMaster, error: achMasterErr } = await supabase
    .from('achievements_master')
    .select('*')
    .eq('category', 'burn')
    .order('sort_order', { ascending: true });
  
  if (achMasterErr) {
    console.log(`   ❌ Error: ${achMasterErr.message}`);
  } else if (achMaster.length === 0) {
    console.log('   ⚠️  No burn achievements found in achievements_master!');
  } else {
    achMaster.forEach(ach => {
      console.log(`\n   📋 ${ach.title}`);
      console.log(`      Key: ${ach.achievement_key}`);
      console.log(`      Required: ${ach.required_count} burns`);
      console.log(`      Reward: ${ach.neft_reward} NEFT + ${ach.xp_reward} XP`);
    });
  }
  
  console.log('\n═══════════════════════════════════════════════════════════\n');
  
  // 3. Check actual achievement status from function
  console.log('3️⃣ CURRENT ACHIEVEMENT STATUS:');
  const { data: statusData, error: statusErr } = await supabase.rpc('get_user_achievement_status', {
    user_wallet: testWallet
  });
  
  if (statusErr) {
    console.log(`   ❌ Error: ${statusErr.message}`);
  } else {
    let achievements = typeof statusData === 'string' ? JSON.parse(statusData) : statusData;
    const burnAchs = achievements.filter(a => a.category === 'burn');
    
    if (burnAchs.length === 0) {
      console.log('   ⚠️  No burn achievements returned by function!');
    } else {
      burnAchs.forEach(ach => {
        console.log(`\n   ${ach.icon} ${ach.title}`);
        console.log(`      Progress: ${ach.current_progress}/${ach.required_count}`);
        console.log(`      Percentage: ${ach.progress_percentage}%`);
        console.log(`      Status: ${ach.status}`);
        console.log(`      Claimed: ${ach.claimed_at ? 'Yes' : 'No'}`);
        
        // Check for bugs
        if (burnsData && burnsData.length !== ach.current_progress) {
          console.log(`      ⚠️  BUG: current_progress (${ach.current_progress}) doesn't match nft_burns count (${burnsData.length})!`);
        }
      });
    }
  }
  
  console.log('\n═══════════════════════════════════════════════════════════\n');
  
  // 4. Summary
  console.log('4️⃣ SYSTEM ANALYSIS SUMMARY:\n');
  
  const actualBurns = burnsData ? burnsData.length : 0;
  console.log(`   Actual burns in database: ${actualBurns}`);
  
  if (statusData) {
    let achievements = typeof statusData === 'string' ? JSON.parse(statusData) : statusData;
    const firstBurn = achievements.find(a => a.achievement_key === 'first_burn');
    const burnEnthusiast = achievements.find(a => a.achievement_key === 'burn_enthusiast');
    const burnMaster = achievements.find(a => a.achievement_key === 'burn_master');
    
    console.log('\n   Achievement Progress:');
    if (firstBurn) {
      console.log(`   • First Burn (1 burn): ${firstBurn.status} ${firstBurn.status === 'completed' ? '✅' : '⏳'}`);
    }
    if (burnEnthusiast) {
      console.log(`   • Burn Enthusiast (10 burns): ${burnEnthusiast.current_progress}/10 - ${burnEnthusiast.status}`);
    }
    if (burnMaster) {
      console.log(`   • Burn Master (50 burns): ${burnMaster.current_progress}/50 - ${burnMaster.status}`);
    }
    
    // Final verdict
    console.log('\n   ═══════════════════════════════════════════════════');
    if (actualBurns > 0 && firstBurn && firstBurn.status === 'completed') {
      console.log('   ✅ SYSTEM WORKING CORRECTLY!');
      console.log('   Burns are being tracked and achievements are updating.');
    } else if (actualBurns > 0 && (!firstBurn || firstBurn.status !== 'completed')) {
      console.log('   ⚠️  POTENTIAL BUG!');
      console.log('   User has burns but First Burn achievement not completed.');
    } else if (actualBurns === 0) {
      console.log('   ℹ️  NO BURNS YET');
      console.log('   System will be tested after first burn.');
    }
    console.log('   ═══════════════════════════════════════════════════');
  }
  
  console.log('\n═══════════════════════════════════════════════════════════\n');
}

analyzeSystem().catch(console.error);
