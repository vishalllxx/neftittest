// Verification script to test the fixed daily claim system
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('\n========================================');
console.log('🔍 VERIFYING DAILY CLAIM FIX');
console.log('========================================\n');

const supabase = createClient(supabaseUrl, supabaseKey);

async function verifyFix() {
  console.log('Testing 7-day progressive cycle...\n');
  
  const expected = [
    { day: 1, neft: 5, xp: 5 },
    { day: 2, neft: 8, xp: 8 },
    { day: 3, neft: 12, xp: 12 },
    { day: 4, neft: 17, xp: 17 },
    { day: 5, neft: 22, xp: 22 },
    { day: 6, neft: 30, xp: 30 },
    { day: 7, neft: 35, xp: 35 },
    { day: 8, neft: 5, xp: 5 }, // Cycle repeats
  ];

  let allPass = true;

  for (const exp of expected) {
    const { data, error } = await supabase.rpc('calculate_daily_reward', {
      streak_count: exp.day,
      user_wallet: '0xTEST'
    });

    if (error) {
      console.log(`❌ Day ${exp.day}: ERROR - ${error.message}`);
      allPass = false;
      continue;
    }

    const result = Array.isArray(data) ? data[0] : data;
    const totalNeft = parseFloat(result.base_neft || 0) + parseFloat(result.bonus_neft || 0);
    const totalXp = parseInt(result.base_xp || 0) + parseInt(result.bonus_xp || 0);
    
    const pass = (totalNeft === exp.neft && totalXp === exp.xp);
    const icon = pass ? '✅' : '❌';
    
    console.log(`${icon} Day ${exp.day}: ${totalNeft} NEFT + ${totalXp} XP (Expected: ${exp.neft} NEFT + ${exp.xp} XP)`);
    
    if (!pass) allPass = false;
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Testing Dashboard Function...\n');

  const { data: dashboard, error: dashError } = await supabase.rpc('get_daily_claim_dashboard', {
    user_wallet: '0xTEST_NEW'
  });

  if (dashError) {
    console.log('❌ Dashboard ERROR:', dashError.message);
    allPass = false;
  } else {
    console.log('✅ Dashboard function works!');
    const dash = Array.isArray(dashboard) ? dashboard[0] : dashboard;
    console.log(`   Next reward: ${dash.neft_reward} NEFT + ${dash.xp_reward} XP`);
    console.log(`   Cycle day: ${dash.cycle_day}`);
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Checking Milestones...\n');

  const { data: milestones, error: milestoneErr } = await supabase
    .from('daily_claim_milestones')
    .select('*')
    .order('milestone_day');

  if (milestoneErr) {
    console.log('❌ Milestones ERROR:', milestoneErr.message);
    allPass = false;
  } else if (milestones.length === 0) {
    console.log('❌ No milestones found');
    allPass = false;
  } else {
    console.log(`✅ Found ${milestones.length} milestones:`);
    milestones.forEach(m => {
      const total = parseFloat(m.base_neft_reward) + parseFloat(m.bonus_neft_reward);
      console.log(`   Day ${m.milestone_day}: ${m.milestone_name} (${total} NEFT total)`);
    });
  }

  console.log('\n========================================');
  if (allPass) {
    console.log('✅ ALL TESTS PASSED!');
    console.log('🎉 Daily claim system is now working correctly!');
  } else {
    console.log('❌ SOME TESTS FAILED');
    console.log('Please check the errors above');
  }
  console.log('========================================\n');
}

verifyFix().catch(console.error);
