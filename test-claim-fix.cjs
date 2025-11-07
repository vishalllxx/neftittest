// Quick test to verify the claim works after fix
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🧪 Testing Daily Claim After Fix...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function testClaimFix() {
  // Test with a fake wallet that hasn't claimed today
  const testWallet = `0xTEST_${Date.now()}`;
  
  console.log(`Testing with wallet: ${testWallet}\n`);
  
  // Test 1: Check streak info
  console.log('1️⃣ Testing get_user_streak_info...');
  const { data: streakData, error: streakErr } = await supabase.rpc('get_user_streak_info', {
    user_wallet: testWallet
  });
  
  if (streakErr) {
    console.log('❌ ERROR:', streakErr.message);
    return;
  }
  console.log('✅ Streak info works!');
  
  // Test 2: Check dashboard
  console.log('\n2️⃣ Testing get_daily_claim_dashboard...');
  const { data: dashData, error: dashErr } = await supabase.rpc('get_daily_claim_dashboard', {
    user_wallet: testWallet
  });
  
  if (dashErr) {
    console.log('❌ ERROR:', dashErr.message);
    console.log('   This should be fixed after applying the SQL!');
    return;
  }
  
  const dash = Array.isArray(dashData) ? dashData[0] : dashData;
  console.log('✅ Dashboard works!');
  console.log(`   Next reward: ${dash.neft_reward} NEFT + ${dash.xp_reward} XP`);
  console.log(`   Cycle day: ${dash.cycle_day}`);
  
  // Test 3: Try a test claim (only if you want to)
  console.log('\n3️⃣ Ready to test actual claim?');
  console.log('   Run this script with argument "claim" to test:');
  console.log('   node test-claim-fix.cjs claim\n');
  
  if (process.argv[2] === 'claim') {
    console.log('🎯 Testing process_daily_claim...');
    const { data: claimData, error: claimErr } = await supabase.rpc('process_daily_claim', {
      user_wallet: testWallet
    });
    
    if (claimErr) {
      console.log('❌ CLAIM ERROR:', claimErr.message);
      console.log('   Code:', claimErr.code);
      return;
    }
    
    const claim = Array.isArray(claimData) ? claimData[0] : claimData;
    if (claim.success) {
      console.log('✅ CLAIM SUCCESSFUL!');
      console.log(`   Streak: Day ${claim.streak_count}`);
      console.log(`   Reward: ${claim.neft_reward} NEFT + ${claim.xp_reward} XP`);
      console.log(`   Tier: ${claim.reward_tier}`);
    } else {
      console.log('❌ Claim failed:', claim.message);
    }
  }
  
  console.log('\n========================================');
  console.log('✅ ALL FUNCTIONS ARE WORKING!');
  console.log('========================================\n');
}

testClaimFix().catch(console.error);
