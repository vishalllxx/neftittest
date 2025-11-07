// Test the actual get_user_achievement_status function
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔍 TESTING get_user_achievement_status FUNCTION...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function testFunction() {
  const testWallet = 'social:discord:1298226044970930248';
  
  console.log(`Testing with wallet: ${testWallet}\n`);
  
  // 1. Check user_streaks first
  console.log('1️⃣ Checking user_streaks data...');
  const { data: streakData, error: streakErr } = await supabase
    .from('user_streaks')
    .select('*')
    .eq('wallet_address', testWallet)
    .single();
  
  if (streakErr) {
    console.log('❌ Error:', streakErr.message);
  } else {
    console.log('✅ User Streak Data:');
    console.log(`   Current Streak: ${streakData.current_streak}`);
    console.log(`   Total Claims: ${streakData.total_claims}`);
    console.log(`   Last Claim: ${streakData.last_claim_date}\n`);
  }
  
  // 2. Test the function
  console.log('2️⃣ Calling get_user_achievement_status...');
  const { data: achData, error: achErr } = await supabase.rpc('get_user_achievement_status', {
    user_wallet: testWallet
  });
  
  if (achErr) {
    console.log('❌ Function Error:', achErr.message);
    console.log('   Full error:', JSON.stringify(achErr, null, 2));
    return;
  }
  
  console.log('✅ Function returned successfully!\n');
  
  // Parse the response
  let achievements = [];
  if (typeof achData === 'string') {
    try {
      achievements = JSON.parse(achData);
    } catch (e) {
      console.log('Response is string but not JSON:', achData);
      return;
    }
  } else if (Array.isArray(achData)) {
    achievements = achData;
  } else {
    achievements = [achData];
  }
  
  console.log(`Total achievements: ${achievements.length}\n`);
  
  // Find check-in achievements
  const checkinAchs = achievements.filter(a => 
    a.category === 'checkin' || 
    a.achievement_key?.includes('checkin') ||
    a.title?.includes('Check-in') ||
    a.title?.includes('Visitor') ||
    a.title?.includes('Dedicated')
  );
  
  if (checkinAchs.length === 0) {
    console.log('❌ No check-in achievements found!');
    console.log('   Available categories:', [...new Set(achievements.map(a => a.category))]);
    console.log('\n   First 3 achievements:');
    achievements.slice(0, 3).forEach(a => {
      console.log(`   - ${a.title || a.achievement_key} (${a.category})`);
    });
  } else {
    console.log('✅ CHECK-IN ACHIEVEMENTS FOUND:\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    checkinAchs.forEach(ach => {
      console.log(`📋 ${ach.title}`);
      console.log(`   Key: ${ach.achievement_key}`);
      console.log(`   Required: ${ach.required_count} claims`);
      console.log(`   Current Progress: ${ach.current_progress}/${ach.required_count}`);
      console.log(`   Progress %: ${ach.progress_percentage}%`);
      console.log(`   Status: ${ach.status}`);
      console.log(`   Completed: ${ach.completed_at || 'Not completed'}`);
      console.log(`   Claimed: ${ach.claimed_at || 'Not claimed'}`);
      
      // Check if it's wrong
      if (streakData && streakData.total_claims < ach.required_count && ach.status === 'completed') {
        console.log(`   ⚠️  BUG: Status is "completed" but user only has ${streakData.total_claims} claims!`);
      }
      
      if (streakData && ach.current_progress !== streakData.total_claims) {
        console.log(`   ⚠️  BUG: Progress (${ach.current_progress}) doesn't match total_claims (${streakData.total_claims})!`);
      }
      
      console.log('');
    });
  }
  
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}

testFunction().catch(console.error);
