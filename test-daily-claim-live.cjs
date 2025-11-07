// Test script to check actual Supabase daily claim implementation
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('========================================');
console.log('🔍 DAILY CLAIM SYSTEM LIVE TEST');
console.log('========================================\n');

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

console.log('✅ Supabase credentials found');
console.log(`📍 URL: ${supabaseUrl}\n`);

const supabase = createClient(supabaseUrl, supabaseKey);

async function testDailyClaimSystem() {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('1️⃣  CHECKING DATABASE FUNCTIONS');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  try {
    // Test 1: Check calculate_daily_reward function
    console.log('📋 Testing: calculate_daily_reward(1, \'0xTEST\')');
    const { data: reward1, error: err1 } = await supabase.rpc('calculate_daily_reward', {
      streak_count: 1,
      user_wallet: '0xTEST'
    });
    
    if (err1) {
      console.log('❌ calculate_daily_reward ERROR:', err1.message);
      console.log('   Code:', err1.code);
    } else {
      console.log('✅ calculate_daily_reward EXISTS');
      console.log('   Day 1 Reward:', JSON.stringify(reward1, null, 2));
    }

    // Test 2: Check calculate_progressive_daily_reward function
    console.log('\n📋 Testing: calculate_progressive_daily_reward(1)');
    const { data: progressive1, error: err2 } = await supabase.rpc('calculate_progressive_daily_reward', {
      streak_day: 1
    });
    
    if (err2) {
      console.log('❌ calculate_progressive_daily_reward ERROR:', err2.message);
      console.log('   Code:', err2.code);
    } else {
      console.log('✅ calculate_progressive_daily_reward EXISTS');
      console.log('   Day 1 Reward:', JSON.stringify(progressive1, null, 2));
    }

    // Test 3: Check get_user_streak_info function
    console.log('\n📋 Testing: get_user_streak_info(\'0xTEST\')');
    const { data: streakInfo, error: err3 } = await supabase.rpc('get_user_streak_info', {
      user_wallet: '0xTEST'
    });
    
    if (err3) {
      console.log('❌ get_user_streak_info ERROR:', err3.message);
    } else {
      console.log('✅ get_user_streak_info EXISTS');
      console.log('   Result:', JSON.stringify(streakInfo, null, 2));
    }

    // Test 4: Check get_daily_claim_dashboard function
    console.log('\n📋 Testing: get_daily_claim_dashboard(\'0xTEST\')');
    const { data: dashboard, error: err4 } = await supabase.rpc('get_daily_claim_dashboard', {
      user_wallet: '0xTEST'
    });
    
    if (err4) {
      console.log('❌ get_daily_claim_dashboard ERROR:', err4.message);
    } else {
      console.log('✅ get_daily_claim_dashboard EXISTS');
      const dashResult = Array.isArray(dashboard) ? dashboard[0] : dashboard;
      console.log('   Dashboard Data:');
      console.log('   - Next NEFT Reward:', dashResult?.next_neft_reward || dashResult?.neft_reward || 'N/A');
      console.log('   - Next XP Reward:', dashResult?.next_xp_reward || dashResult?.xp_reward || 'N/A');
      console.log('   - Reward Tier:', dashResult?.next_reward_tier || dashResult?.reward_tier || 'N/A');
      console.log('   - Can Claim:', dashResult?.can_claim_today || 'N/A');
    }

    // Test 5: Check process_daily_claim function (don't actually call it)
    console.log('\n📋 Testing: process_daily_claim function exists');
    console.log('   (Not executing to avoid creating test claims)');

  } catch (error) {
    console.error('❌ Function test error:', error.message);
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('2️⃣  CHECKING DATABASE TABLES');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Check tables
  const tables = ['user_streaks', 'daily_claims', 'daily_claim_milestones', 'user_balances'];
  
  for (const table of tables) {
    try {
      const { data, error } = await supabase.from(table).select('*').limit(1);
      
      if (error) {
        console.log(`❌ Table "${table}": ${error.message}`);
      } else {
        console.log(`✅ Table "${table}": Exists and accessible`);
      }
    } catch (err) {
      console.log(`❌ Table "${table}": ${err.message}`);
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('3️⃣  TESTING REWARD CALCULATIONS (Days 1-8)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // Test reward calculations for days 1-8
  console.log('Testing which reward function is actually being used:\n');
  
  const expectedProgressive = [
    { day: 1, neft: 5, xp: 5, tier: 'Day 1 - Fresh Start' },
    { day: 2, neft: 8, xp: 8, tier: 'Day 2 - Building Momentum' },
    { day: 3, neft: 12, xp: 12, tier: 'Day 3 - Getting Stronger' },
    { day: 4, neft: 17, xp: 17, tier: 'Day 4 - Steady Progress' },
    { day: 5, neft: 22, xp: 22, tier: 'Day 5 - Consistent Effort' },
    { day: 6, neft: 30, xp: 30, tier: 'Day 6 - Almost There' },
    { day: 7, neft: 35, xp: 35, tier: 'Day 7 - Weekly Champion' },
    { day: 8, neft: 5, xp: 5, tier: 'Day 1 - Fresh Start (Cycle 2)' },
  ];

  for (let i = 1; i <= 8; i++) {
    const { data: rewardData, error: rewardErr } = await supabase.rpc('calculate_daily_reward', {
      streak_count: i,
      user_wallet: '0xTEST'
    });

    if (rewardErr) {
      console.log(`Day ${i}: ❌ Error - ${rewardErr.message}`);
      continue;
    }

    const result = Array.isArray(rewardData) ? rewardData[0] : rewardData;
    const totalNeft = (parseFloat(result?.base_neft || 0) + parseFloat(result?.bonus_neft || 0)).toFixed(1);
    const totalXp = parseInt(result?.base_xp || 0) + parseInt(result?.bonus_xp || 0);
    const expected = expectedProgressive[i - 1];
    
    const matches = (parseFloat(totalNeft) === expected.neft && totalXp === expected.xp);
    const icon = matches ? '✅' : '⚠️';
    
    console.log(`${icon} Day ${i}: ${totalNeft} NEFT + ${totalXp} XP | Tier: ${result?.reward_tier || 'N/A'}`);
    console.log(`   Expected: ${expected.neft} NEFT + ${expected.xp} XP`);
    
    if (!matches) {
      console.log(`   ⚠️  MISMATCH! Database doesn't match 7-day progressive cycle`);
    }
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('4️⃣  CHECKING RECENT CLAIMS');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  try {
    const { data: claims, error: claimsErr } = await supabase
      .from('daily_claims')
      .select('wallet_address, claim_date, streak_count, base_neft_reward, base_xp_reward, reward_tier')
      .order('claimed_at', { ascending: false })
      .limit(10);

    if (claimsErr) {
      console.log('❌ Error fetching claims:', claimsErr.message);
    } else if (!claims || claims.length === 0) {
      console.log('ℹ️  No claims found in database yet');
    } else {
      console.log(`📊 Found ${claims.length} recent claims:\n`);
      claims.forEach((claim, idx) => {
        console.log(`${idx + 1}. Wallet: ${claim.wallet_address.substring(0, 10)}...`);
        console.log(`   Date: ${claim.claim_date}`);
        console.log(`   Streak: Day ${claim.streak_count}`);
        console.log(`   Reward: ${claim.base_neft_reward} NEFT + ${claim.base_xp_reward} XP`);
        console.log(`   Tier: ${claim.reward_tier}\n`);
      });
    }
  } catch (err) {
    console.log('❌ Error checking claims:', err.message);
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('5️⃣  CHECKING MILESTONES');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  try {
    const { data: milestones, error: milestoneErr } = await supabase
      .from('daily_claim_milestones')
      .select('*')
      .order('milestone_day', { ascending: true });

    if (milestoneErr) {
      console.log('❌ Error fetching milestones:', milestoneErr.message);
    } else if (!milestones || milestones.length === 0) {
      console.log('⚠️  No milestones found in database');
    } else {
      console.log(`📊 Found ${milestones.length} milestones:\n`);
      milestones.forEach((milestone) => {
        const totalNeft = parseFloat(milestone.base_neft_reward || 0) + parseFloat(milestone.bonus_neft_reward || 0);
        const totalXp = parseInt(milestone.base_xp_reward || 0) + parseInt(milestone.bonus_xp_reward || 0);
        console.log(`Day ${milestone.milestone_day}: ${milestone.milestone_name}`);
        console.log(`   Reward: ${totalNeft} NEFT + ${totalXp} XP`);
        console.log(`   ${milestone.is_special_milestone ? '⭐ SPECIAL' : ''}${milestone.nft_reward ? ' + NFT' : ''}\n`);
      });
    }
  } catch (err) {
    console.log('❌ Error checking milestones:', err.message);
  }

  console.log('\n========================================');
  console.log('📋 SUMMARY');
  console.log('========================================\n');
  
  console.log('✅ = Working correctly');
  console.log('⚠️  = Exists but has issues');
  console.log('❌ = Not working or missing\n');
  
  console.log('Check the results above to see:');
  console.log('1. Which functions exist in your database');
  console.log('2. Which reward calculation is being used');
  console.log('3. If rewards match the 7-day progressive cycle');
  console.log('4. What actual users are receiving\n');
}

testDailyClaimSystem().catch(console.error);
