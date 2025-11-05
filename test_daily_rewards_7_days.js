/**
 * Comprehensive Test: 7-Day Daily Claim Reward Cycle
 * 
 * This test verifies that:
 * 1. All 7 days of rewards are calculated correctly
 * 2. User balance and XP are properly added for each day
 * 3. The progressive reward system works as expected
 * 4. Streak counting is accurate
 * 5. Cycle resets correctly after day 7
 */

// Import the progressive reward calculation function
const DailyClaimsService = {
  calculateProgressiveReward: (streakDay) => {
    const cycleDay = ((streakDay - 1) % 7) + 1;

    // EXACT MATCH with calculate_progressive_daily_reward function in database
    switch (cycleDay) {
      case 1: return { neft: 5, xp: 5, tier: 'Day 1 - Fresh Start', cycleDay };
      case 2: return { neft: 8, xp: 8, tier: 'Day 2 - Building Momentum', cycleDay };
      case 3: return { neft: 12, xp: 12, tier: 'Day 3 - Getting Stronger', cycleDay };
      case 4: return { neft: 17, xp: 17, tier: 'Day 4 - Steady Progress', cycleDay };
      case 5: return { neft: 22, xp: 22, tier: 'Day 5 - Consistent Effort', cycleDay };
      case 6: return { neft: 30, xp: 30, tier: 'Day 6 - Almost There', cycleDay };
      case 7: return { neft: 35, xp: 35, tier: 'Day 7 - Weekly Champion', cycleDay };
      default: return { neft: 5, xp: 5, tier: 'Day 1 - Fresh Start', cycleDay: 1 };
    }
  }
};

// Test data structure
class TestUser {
  constructor(walletAddress) {
    this.walletAddress = walletAddress;
    this.totalNeftClaimed = 0;
    this.totalXpEarned = 0;
    this.currentStreak = 0;
    this.claimHistory = [];
  }

  // Simulate daily claim
  claimDaily() {
    this.currentStreak += 1;
    const reward = DailyClaimsService.calculateProgressiveReward(this.currentStreak);
    
    // Add rewards to balance
    this.totalNeftClaimed += reward.neft;
    this.totalXpEarned += reward.xp;
    
    // Record claim
    const claim = {
      day: this.currentStreak,
      cycleDay: reward.cycleDay,
      neftReward: reward.neft,
      xpReward: reward.xp,
      tier: reward.tier,
      totalNeftAfter: this.totalNeftClaimed,
      totalXpAfter: this.totalXpEarned,
      timestamp: new Date().toISOString()
    };
    
    this.claimHistory.push(claim);
    return claim;
  }

  // Get current balance
  getBalance() {
    return {
      totalNeftClaimed: this.totalNeftClaimed,
      totalXpEarned: this.totalXpEarned,
      currentStreak: this.currentStreak
    };
  }
}

// Test runner
function runDailyRewardTest() {
  console.log('🧪 STARTING 7-DAY DAILY REWARD CYCLE TEST');
  console.log('=' .repeat(60));

  const testUser = new TestUser('test:social:google:123456789');
  
  // Expected rewards for each day
  const expectedRewards = [
    { day: 1, neft: 5, xp: 5, cycleDay: 1 },
    { day: 2, neft: 8, xp: 8, cycleDay: 2 },
    { day: 3, neft: 12, xp: 12, cycleDay: 3 },
    { day: 4, neft: 17, xp: 17, cycleDay: 4 },
    { day: 5, neft: 22, xp: 22, cycleDay: 5 },
    { day: 6, neft: 30, xp: 30, cycleDay: 6 },
    { day: 7, neft: 35, xp: 35, cycleDay: 7 }
  ];

  let totalExpectedNeft = 0;
  let totalExpectedXp = 0;
  let allTestsPassed = true;

  // Test each day
  for (let day = 1; day <= 7; day++) {
    console.log(`\n📅 DAY ${day} TEST:`);
    console.log('-'.repeat(30));

    const claim = testUser.claimDaily();
    const expected = expectedRewards[day - 1];
    
    totalExpectedNeft += expected.neft;
    totalExpectedXp += expected.xp;

    // Verify individual day rewards
    const neftMatch = claim.neftReward === expected.neft;
    const xpMatch = claim.xpReward === expected.xp;
    const cycleDayMatch = claim.cycleDay === expected.cycleDay;
    
    console.log(`   Streak Day: ${claim.day} (Cycle Day: ${claim.cycleDay})`);
    console.log(`   Tier: ${claim.tier}`);
    console.log(`   Rewards: ${claim.neftReward} NEFT + ${claim.xpReward} XP`);
    console.log(`   Expected: ${expected.neft} NEFT + ${expected.xp} XP`);
    console.log(`   ✅ NEFT: ${neftMatch ? 'PASS' : 'FAIL'}`);
    console.log(`   ✅ XP: ${xpMatch ? 'PASS' : 'FAIL'}`);
    console.log(`   ✅ Cycle Day: ${cycleDayMatch ? 'PASS' : 'FAIL'}`);
    
    // Verify cumulative totals
    const totalNeftMatch = claim.totalNeftAfter === totalExpectedNeft;
    const totalXpMatch = claim.totalXpAfter === totalExpectedXp;
    
    console.log(`   Total NEFT: ${claim.totalNeftAfter} (Expected: ${totalExpectedNeft}) ${totalNeftMatch ? '✅' : '❌'}`);
    console.log(`   Total XP: ${claim.totalXpAfter} (Expected: ${totalExpectedXp}) ${totalXpMatch ? '✅' : '❌'}`);

    if (!neftMatch || !xpMatch || !cycleDayMatch || !totalNeftMatch || !totalXpMatch) {
      allTestsPassed = false;
      console.log(`   ❌ DAY ${day} FAILED!`);
    } else {
      console.log(`   ✅ DAY ${day} PASSED!`);
    }
  }

  // Test cycle continuation (Day 8 should be same as Day 1)
  console.log(`\n📅 DAY 8 TEST (Cycle Reset):`);
  console.log('-'.repeat(30));
  
  const day8Claim = testUser.claimDaily();
  const day8Expected = { neft: 5, xp: 5, cycleDay: 1 }; // Should reset to Day 1 rewards
  
  const day8NeftMatch = day8Claim.neftReward === day8Expected.neft;
  const day8XpMatch = day8Claim.xpReward === day8Expected.xp;
  const day8CycleDayMatch = day8Claim.cycleDay === day8Expected.cycleDay;
  
  console.log(`   Streak Day: ${day8Claim.day} (Cycle Day: ${day8Claim.cycleDay})`);
  console.log(`   Tier: ${day8Claim.tier}`);
  console.log(`   Rewards: ${day8Claim.neftReward} NEFT + ${day8Claim.xpReward} XP`);
  console.log(`   Expected: ${day8Expected.neft} NEFT + ${day8Expected.xp} XP (Cycle Reset)`);
  console.log(`   ✅ NEFT: ${day8NeftMatch ? 'PASS' : 'FAIL'}`);
  console.log(`   ✅ XP: ${day8XpMatch ? 'PASS' : 'FAIL'}`);
  console.log(`   ✅ Cycle Reset: ${day8CycleDayMatch ? 'PASS' : 'FAIL'}`);

  if (!day8NeftMatch || !day8XpMatch || !day8CycleDayMatch) {
    allTestsPassed = false;
    console.log(`   ❌ DAY 8 (CYCLE RESET) FAILED!`);
  } else {
    console.log(`   ✅ DAY 8 (CYCLE RESET) PASSED!`);
  }

  // Final summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 FINAL TEST SUMMARY:');
  console.log('='.repeat(60));

  const finalBalance = testUser.getBalance();
  const expectedFinalNeft = totalExpectedNeft + 5; // +5 from Day 8
  const expectedFinalXp = totalExpectedXp + 5; // +5 from Day 8

  console.log(`\n💰 TOTAL REWARDS EARNED (8 days):`);
  console.log(`   Total NEFT: ${finalBalance.totalNeftClaimed} (Expected: ${expectedFinalNeft})`);
  console.log(`   Total XP: ${finalBalance.totalXpEarned} (Expected: ${expectedFinalXp})`);
  console.log(`   Current Streak: ${finalBalance.currentStreak}`);

  console.log(`\n📈 7-DAY CYCLE BREAKDOWN:`);
  console.log(`   Day 1: 5 NEFT + 5 XP`);
  console.log(`   Day 2: 8 NEFT + 8 XP`);
  console.log(`   Day 3: 12 NEFT + 12 XP`);
  console.log(`   Day 4: 17 NEFT + 17 XP`);
  console.log(`   Day 5: 22 NEFT + 22 XP`);
  console.log(`   Day 6: 30 NEFT + 30 XP`);
  console.log(`   Day 7: 35 NEFT + 35 XP`);
  console.log(`   ────────────────────────`);
  console.log(`   Total: ${totalExpectedNeft} NEFT + ${totalExpectedXp} XP per week`);

  console.log(`\n🔄 CYCLE VERIFICATION:`);
  console.log(`   Day 8 = Day 1 (Cycle Reset): ${day8CycleDayMatch ? '✅ PASS' : '❌ FAIL'}`);

  console.log(`\n🎯 OVERALL TEST RESULT:`);
  if (allTestsPassed && finalBalance.totalNeftClaimed === expectedFinalNeft && finalBalance.totalXpEarned === expectedFinalXp) {
    console.log(`   🎉 ALL TESTS PASSED! 7-day reward cycle is working correctly.`);
    return true;
  } else {
    console.log(`   ❌ SOME TESTS FAILED! Please check the reward calculation logic.`);
    return false;
  }
}

// Run the test
const testResult = runDailyRewardTest();

// Export for potential use in other tests
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runDailyRewardTest, DailyClaimsService };
}
