// Check actual achievement tables in Supabase
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n🔍 CHECKING ACTUAL ACHIEVEMENT DATABASE STRUCTURE...\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkDatabase() {
  console.log('1️⃣ Checking what achievement-related tables exist...\n');
  
  // Try different possible table names
  const possibleTables = [
    'achievement_master',
    'achievements',
    'user_achievements',
    'user_achievement_progress',
    'achievement_definitions'
  ];
  
  for (const tableName of possibleTables) {
    try {
      const { data, error } = await supabase
        .from(tableName)
        .select('*')
        .limit(1);
      
      if (error) {
        console.log(`❌ ${tableName}: Does not exist (${error.message})`);
      } else {
        console.log(`✅ ${tableName}: EXISTS!`);
        if (data && data.length > 0) {
          console.log(`   Sample columns:`, Object.keys(data[0]));
        }
      }
    } catch (err) {
      console.log(`❌ ${tableName}: Error - ${err.message}`);
    }
  }
  
  console.log('\n2️⃣ Checking available RPC functions related to achievements...\n');
  
  // Try calling achievement functions
  const possibleFunctions = [
    'get_user_achievements',
    'get_achievements',
    'claim_achievement',
    'update_user_achievements'
  ];
  
  const testWallet = '0xTEST';
  
  for (const funcName of possibleFunctions) {
    try {
      const { data, error } = await supabase.rpc(funcName, { user_wallet: testWallet });
      
      if (error) {
        console.log(`❌ ${funcName}: ${error.message}`);
      } else {
        console.log(`✅ ${funcName}: EXISTS and works!`);
        if (data && (Array.isArray(data) ? data.length > 0 : Object.keys(data).length > 0)) {
          const sample = Array.isArray(data) ? data[0] : data;
          console.log(`   Returns:`, Object.keys(sample));
        }
      }
    } catch (err) {
      console.log(`❌ ${funcName}: Error - ${err.message}`);
    }
  }
  
  console.log('\n3️⃣ Checking user_streaks table (for check-in count)...\n');
  
  try {
    const { data: streakData, error: streakErr } = await supabase
      .from('user_streaks')
      .select('*')
      .limit(1);
    
    if (streakErr) {
      console.log('❌ user_streaks: Error -', streakErr.message);
    } else {
      console.log('✅ user_streaks: EXISTS');
      if (streakData && streakData.length > 0) {
        console.log('   Columns:', Object.keys(streakData[0]));
      }
    }
  } catch (err) {
    console.log('❌ user_streaks: Error -', err.message);
  }
  
  console.log('\n4️⃣ Testing get_user_achievements with a real wallet...\n');
  
  const realWallet = 'social:discord:1298226044970930248';
  
  try {
    const { data: achData, error: achErr } = await supabase.rpc('get_user_achievements', {
      user_wallet: realWallet
    });
    
    if (achErr) {
      console.log('❌ Error:', achErr.message);
    } else {
      console.log('✅ Success! Found achievements:');
      const achievements = Array.isArray(achData) ? achData : [achData];
      
      // Filter check-in achievements
      const checkinAchs = achievements.filter(a => 
        a.category === 'checkin' || 
        a.achievement_key?.includes('checkin') ||
        a.title?.includes('Check-in') ||
        a.title?.includes('Visitor') ||
        a.title?.includes('Dedicated')
      );
      
      if (checkinAchs.length === 0) {
        console.log('   No check-in achievements found');
        console.log('   Total achievements:', achievements.length);
        if (achievements.length > 0) {
          console.log('   Sample achievement:', achievements[0]);
        }
      } else {
        console.log('\n   CHECK-IN ACHIEVEMENTS:');
        checkinAchs.forEach(ach => {
          console.log(`\n   ${ach.title || ach.achievement_key}`);
          console.log(`   - Key: ${ach.achievement_key}`);
          console.log(`   - Progress: ${ach.current_progress || 0}/${ach.required_count || 0}`);
          console.log(`   - Status: ${ach.status}`);
          console.log(`   - Completed: ${ach.is_completed || false}`);
        });
      }
    }
  } catch (err) {
    console.log('❌ Error:', err.message);
  }
  
  console.log('\n========================================');
  console.log('✅ DATABASE STRUCTURE CHECK COMPLETE');
  console.log('========================================\n');
}

checkDatabase().catch(console.error);
