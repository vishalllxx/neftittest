// Check the actual total_claims value
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔍 CHECKING ACTUAL CLAIM DATA...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkData() {
  const testWallet = 'social:google:100335175710056438027';
  
  console.log(`Wallet: ${testWallet}\n`);
  
  // 1. Check user_streaks
  console.log('1️⃣ USER_STREAKS DATA:');
  const { data: streakData, error: streakErr } = await supabase
    .from('user_streaks')
    .select('*')
    .eq('wallet_address', testWallet)
    .single();
  
  if (streakErr) {
    console.log('❌ Error:', streakErr.message);
  } else {
    console.log(`   Current Streak: ${streakData.current_streak}`);
    console.log(`   Total Claims: ${streakData.total_claims} ⭐`);
    console.log(`   Last Claim: ${streakData.last_claim_date}\n`);
  }
  
  // 2. Check daily_claims count
  console.log('2️⃣ DAILY_CLAIMS COUNT:');
  const { data: claimsData, error: claimsErr } = await supabase
    .from('daily_claims')
    .select('claim_date')
    .eq('wallet_address', testWallet)
    .order('claim_date', { ascending: true });
  
  if (claimsErr) {
    console.log('❌ Error:', claimsErr.message);
  } else {
    console.log(`   Total claim records: ${claimsData.length}`);
    if (claimsData.length > 0) {
      console.log('   Claim dates:');
      claimsData.forEach((claim, i) => {
        console.log(`   ${i + 1}. ${claim.claim_date}`);
      });
    }
    console.log('');
  }
  
  // 3. Check achievement status
  console.log('3️⃣ ACHIEVEMENT STATUS:');
  const { data: achData, error: achErr } = await supabase.rpc('get_user_achievement_status', {
    user_wallet: testWallet
  });
  
  if (achErr) {
    console.log('❌ Error:', achErr.message);
  } else {
    let achievements = typeof achData === 'string' ? JSON.parse(achData) : achData;
    const starterAch = achievements.find(a => a.achievement_key === 'checkin_starter');
    
    if (starterAch) {
      console.log('   Check-in Starter:');
      console.log(`   - Required: ${starterAch.required_count} claims`);
      console.log(`   - Current Progress: ${starterAch.current_progress}`);
      console.log(`   - Progress %: ${starterAch.progress_percentage}%`);
      console.log(`   - Status: ${starterAch.status}`);
      console.log('');
      
      // Check if it's wrong
      if (streakData && streakData.total_claims < starterAch.required_count && starterAch.status === 'completed') {
        console.log('   ⚠️  BUG CONFIRMED:');
        console.log(`   User has ${streakData.total_claims} claims but achievement status is "completed"!`);
        console.log(`   Achievement requires ${starterAch.required_count} claims.`);
      } else if (streakData && streakData.total_claims >= starterAch.required_count && starterAch.status === 'completed') {
        console.log('   ✅ ACHIEVEMENT IS CORRECT:');
        console.log(`   User has ${streakData.total_claims} claims, achievement requires ${starterAch.required_count}.`);
      }
    }
  }
}

checkData().catch(console.error);
