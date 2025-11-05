# Global Balance Context Implementation

## Problem Solved

### Before (Multiple Balance Loading Issues ❌):
```
User visits Staking page → Loads balance
User visits Burn page → Loads balance AGAIN
User visits Activity page → Loads balance AGAIN
User claims reward → Each page reloads balance separately
Result: Redundant API calls, inconsistent UI, poor UX
```

### After (Global Balance Context ✅):
```
User logs in → Balance loads ONCE globally
User navigates to any page → Uses cached balance (instant!)
User claims reward → Balance updates EVERYWHERE automatically
Result: Single source of truth, smooth operations, better performance
```

---

## Solution: UserBalanceContext

### ✨ **What It Does:**

1. **Single Global Balance State** - One balance for entire website
2. **Automatic Loading** - Loads once when user authenticates
3. **Real-time Updates** - Listens to all balance-changing events
4. **Smart Caching** - No redundant API calls
5. **Optimistic Updates** - Instant UI feedback before backend confirms
6. **MetaMask Support** - Clears balance when account switches

---

## Architecture

### **Balance Aggregation (from MEMORY):**
```
UserBalanceService.getUserBalance()
   ↓
get_user_complete_balance() [Supabase RPC]
   ↓
Aggregates from:
   ├── Campaign Rewards (campaign_rewards table)
   ├── Daily Claim Rewards (daily_claims table)
   ├── Achievement Rewards (user_achievements table)
   ├── Staking Claim Rewards (staking_rewards table)
   └── Referral Rewards (referral_rewards table)
   ↓
Returns: { available_neft, total_xp_earned, staked_amount, ... }
```

### **Event Flow:**
```
Service Action (e.g., claim reward)
   ↓
Calls: userBalanceService.requestBalanceSync()
   ↓
Updates database (sync_user_balance_from_all_sources)
   ↓
Triggers Supabase real-time subscription
   ↓
UserBalanceContext receives update
   ↓
Updates global balance state
   ↓
All components re-render with new balance
   ✅ MainNav shows updated NEFT/XP
   ✅ Staking page shows updated available balance
   ✅ Burn page shows updated balance
```

---

## Files Created/Modified

### **1. Created: UserBalanceContext.tsx**
**Location:** `src/contexts/UserBalanceContext.tsx`

**Features:**
- ✅ Global balance state management
- ✅ Auto-loads on authentication
- ✅ Subscribes to real-time updates from UserBalanceService
- ✅ Listens to 13+ balance-changing events
- ✅ Optimistic updates for instant UI feedback
- ✅ Clears balance on wallet change
- ✅ Force refresh capability

**API:**
```typescript
const { balance, isLoading, refreshBalance, updateBalanceOptimistic } = useUserBalance();

// balance: UserBalance | null
// isLoading: boolean
// refreshBalance: (forceRefresh?: boolean) => Promise<void>
// updateBalanceOptimistic: (updates: Partial<UserBalance>) => void
```

### **2. Modified: MainNav.tsx**
**Location:** `src/components/layout/MainNav.tsx`

**Changes:**
- ✅ Removed 3 `useEffect` hooks (118 lines deleted!)
- ✅ Removed local `userBalance` state
- ✅ Removed local `isLoadingBalance` state
- ✅ Removed all event listeners
- ✅ Removed subscription management
- ✅ Now uses: `const { balance, isLoading } = useUserBalance();`

**Before:**
```typescript
// 118 lines of balance loading logic
const [userBalance, setUserBalance] = useState<UserBalance | null>(null);
const [isLoadingBalance, setIsLoadingBalance] = useState(false);

useEffect(() => {
  // Load balance
  // Subscribe to updates
  // Listen to events
}, [isAuthenticated, walletAddress]);

useEffect(() => {
  // Listen for legacy events
}, [isAuthenticated, walletAddress]);

useEffect(() => {
  // Listen for reward events
}, [isAuthenticated, walletAddress]);
```

**After:**
```typescript
// 1 line!
const { balance: userBalance, isLoading: isLoadingBalance } = useUserBalance();
```

### **3. Modified: App.tsx**
**Location:** `src/App.tsx`

**Changes:**
- ✅ Added `UserBalanceProvider` wrapper
- ✅ Wraps entire app (below WalletProvider, above NFTProvider)

**Provider Hierarchy:**
```tsx
<QueryClientProvider>
  <ThirdwebProvider>
    <SuiWalletProvider>
      <WalletProvider>
        <UserBalanceProvider> ← NEW!
          <NFTProvider>
            <App Routes>
          </NFTProvider>
        </UserBalanceProvider>
      </WalletProvider>
    </SuiWalletProvider>
  </ThirdwebProvider>
</QueryClientProvider>
```

---

## Events Listened By Context

The UserBalanceContext automatically refreshes when ANY of these events fire:

1. ✅ `balanceUpdate` - Generic balance update
2. ✅ `rewardClaimed` - Legacy reward claim
3. ✅ `stakingUpdate` - Staking operation
4. ✅ `unstakingUpdate` - Unstaking operation
5. ✅ `rewards-claimed` - Rewards claimed
6. ✅ `tokens-staked` - Token staking
7. ✅ `tokens-unstaked` - Token unstaking
8. ✅ `daily-reward-claimed` - Daily claim
9. ✅ `achievement-unlocked` - Achievement reward
10. ✅ `campaign-reward-claimed` - Campaign reward
11. ✅ `referral-reward-earned` - Referral reward
12. ✅ `balance-sync-completed` - Backend sync complete
13. ✅ `wallet-changed` - MetaMask account switch

---

## Usage Examples

### **Example 1: Display Balance in Any Component**
```typescript
import { useUserBalance } from '@/contexts/UserBalanceContext';

const MyComponent = () => {
  const { balance, isLoading } = useUserBalance();

  if (isLoading) return <div>Loading...</div>;
  
  return (
    <div>
      <p>NEFT: {balance?.available_neft || 0}</p>
      <p>XP: {balance?.total_xp_earned || 0}</p>
    </div>
  );
};
```

### **Example 2: Force Refresh After Action**
```typescript
import { useUserBalance } from '@/contexts/UserBalanceContext';

const ClaimButton = () => {
  const { refreshBalance } = useUserBalance();

  const handleClaim = async () => {
    await claimReward();
    await refreshBalance(true); // Force fresh data from database
  };

  return <button onClick={handleClaim}>Claim Reward</button>;
};
```

### **Example 3: Optimistic Update**
```typescript
import { useUserBalance } from '@/contexts/UserBalanceContext';

const QuickStake = () => {
  const { balance, updateBalanceOptimistic } = useUserBalance();

  const handleStake = async (amount: number) => {
    // Immediate UI feedback
    updateBalanceOptimistic({
      available_neft: (balance?.available_neft || 0) - amount,
      staked_amount: (balance?.staked_amount || 0) + amount
    });

    // Real backend call (will update with actual values)
    await stakeTokens(amount);
  };

  return <button onClick={() => handleStake(100)}>Stake 100 NEFT</button>;
};
```

---

## Benefits

### **1. Performance**
- ❌ Before: 3+ API calls per page navigation
- ✅ After: 1 API call on login, cached for all pages

### **2. Consistency**
- ❌ Before: Different balance values across pages
- ✅ After: Single source of truth, always consistent

### **3. Real-time Updates**
- ❌ Before: Manual refresh needed to see balance updates
- ✅ After: Automatic updates via Supabase subscriptions

### **4. Developer Experience**
- ❌ Before: Copy-paste balance logic to each page
- ✅ After: One hook `useUserBalance()` - done!

### **5. User Experience**
- ❌ Before: "Loading..." on every page navigation
- ✅ After: Instant balance display, smooth transitions

---

## Integration with Existing Services

### **Services That Update Balance:**

All these services dispatch events that trigger balance refresh:

1. **CampaignRewardsService** → `campaign-reward-claimed`
2. **DailyClaimsService** → `daily-reward-claimed`
3. **AchievementsService** → `achievement-unlocked`
4. **ReferralService** → `referral-reward-earned`
5. **StakingService** → `rewards-claimed`, `tokens-staked`, `tokens-unstaked`

### **No Code Changes Needed!**

These services already call `userBalanceService.requestBalanceSync()` which:
1. Updates database
2. Fires events
3. Triggers context refresh
4. Updates UI globally

---

## Testing Checklist

### **Test 1: Initial Load**
- [ ] Login with wallet
- [ ] Balance appears in MainNav immediately
- [ ] Navigate to Staking → Balance already there (no loading)
- [ ] Navigate to Burn → Balance already there (no loading)

### **Test 2: Reward Claims**
- [ ] Claim daily reward
- [ ] Balance updates in MainNav without refresh
- [ ] Navigate to any page → Updated balance shown

### **Test 3: Staking Operations**
- [ ] Stake 100 NEFT
- [ ] Available balance decreases in MainNav
- [ ] Staked amount increases
- [ ] All pages show updated values

### **Test 4: MetaMask Account Switch**
- [ ] Switch MetaMask account
- [ ] Balance clears
- [ ] New account's balance loads automatically

### **Test 5: Multiple Rewards**
- [ ] Claim campaign reward → Balance updates
- [ ] Claim achievement reward → Balance updates again
- [ ] Both updates reflected everywhere

---

## Troubleshooting

### **Issue: Balance not updating after action**

**Solution:**
```typescript
// Ensure your service dispatches the event:
window.dispatchEvent(new Event('balance-sync-completed'));

// Or use UserBalanceService:
await userBalanceService.requestBalanceSync(walletAddress);
```

### **Issue: Balance shows 0**

**Check:**
1. Is user authenticated? `isAuthenticated === true`
2. Is wallet address valid? `walletAddress !== null`
3. Does user have balance in database? Check `user_balances` table
4. Is `get_user_complete_balance()` RPC function deployed?

### **Issue: Balance loads on every page**

**Check:**
1. Is `UserBalanceProvider` in `App.tsx`? Should be at app root
2. Are you using `useUserBalance()` hook? Not creating local state
3. Check console for "🔄 [BalanceContext] Loading balance" - should only appear once

---

## Migration Guide

### **For Existing Pages Using Local Balance State:**

**Before:**
```typescript
const [userBalance, setUserBalance] = useState<UserBalance | null>(null);
const [isLoadingBalance, setIsLoadingBalance] = useState(false);

useEffect(() => {
  const loadBalance = async () => {
    setIsLoadingBalance(true);
    const balance = await userBalanceService.getUserBalance(walletAddress);
    setUserBalance(balance);
    setIsLoadingBalance(false);
  };
  loadBalance();
}, [walletAddress]);
```

**After:**
```typescript
const { balance: userBalance, isLoading: isLoadingBalance } = useUserBalance();
```

**That's it! Delete all the useEffect and loading logic!**

---

## Summary

✅ **Created:** Global UserBalanceContext for entire app  
✅ **Updated:** MainNav to use global context (118 lines removed!)  
✅ **Wrapped:** App.tsx with UserBalanceProvider  
✅ **Result:** Single source of truth, smooth balance updates, better performance

**Balance now aggregates from:**
- Campaign Rewards ✅
- Daily Claims ✅
- Achievements ✅
- Staking Rewards ✅
- Referral Rewards ✅

**Auto-updates on:**
- Any reward claim ✅
- Any staking operation ✅
- MetaMask account switch ✅
- Database changes (via Supabase real-time) ✅

**Available everywhere:**
- MainNav ✅
- Staking Page ✅
- Burn Page ✅
- Activity Page ✅
- Any future page ✅

🎉 **The balance is now truly global for the entire NEFTIT platform!**
