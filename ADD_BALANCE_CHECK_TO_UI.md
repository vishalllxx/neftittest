# ✅ Add Balance Check to Burn Button

## What We're Adding

**Show gas balance status BEFORE user clicks burn button:**
- ✅ Green indicator: "Sufficient balance on all chains"
- ⏳ Blue indicator: "Checking gas balance..."
- ❌ Red indicator: "Insufficient gas balance on X chains"
- 🔒 Disable burn button until balance is verified

---

## Files Already Created

✅ **Hook Created:** `src/hooks/useBalanceCheck.ts`
- Automatically checks balance when NFTs are selected
- Only checks for onchain NFTs
- Returns: `isChecking`, `hasSufficientBalance`, `insufficientChains`, `errorMessage`

✅ **Hook Imported:** Already added to `Burn.tsx` line 57
✅ **Hook Used:** Already added to `Burn.tsx` line 132

---

## What to Add in Burn.tsx

### Step 1: Add Balance Status Indicator

**Location:** After line 859 (after `</div>`) and before line 861 (before `<Button`)

**Add this code:**

```tsx
      {/* Balance Status Message */}
      {selectedNFTs.length > 0 && (selectedNFTs.some(nft => nft.status === 'onchain')) && (
        <div className={cn(
          "w-full p-3 rounded-lg mt-2 flex items-center gap-2",
          isCheckingBalance ? "bg-blue-500/10 border border-blue-500/30" :
          hasSufficientBalance ? "bg-green-500/10 border border-green-500/30" :
          "bg-red-500/10 border border-red-500/30"
        )}>
          {isCheckingBalance ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin text-blue-400" />
              <span className="text-sm text-blue-400">Checking gas balance...</span>
            </>
          ) : hasSufficientBalance ? (
            <>
              <Check className="w-4 h-4 text-green-400" />
              <span className="text-sm text-green-400">✅ Sufficient balance on all chains</span>
            </>
          ) : (
            <>
              <AlertCircle className="w-4 h-4 text-red-400" />
              <span className="text-sm text-red-400">{errorMessage || 'Insufficient gas balance'}</span>
            </>
          )}
        </div>
      )}
```

---

### Step 2: Update Button Disabled State

**Location:** Line 868

**Change from:**
```tsx
        disabled={!canBurn()}
```

**To:**
```tsx
        disabled={!canBurn() || !hasSufficientBalance || isCheckingBalance}
```

---

### Step 3: Update Button Title

**Location:** Line 870

**Change from:**
```tsx
        title={!canBurn() ? "Select NFTs and ensure you have burn chances available" : ""}
```

**To:**
```tsx
        title={
          !canBurn() ? "Select NFTs and ensure you have burn chances available" :
          !hasSufficientBalance ? "Insufficient gas balance on some chains" :
          isCheckingBalance ? "Checking balance..." :
          ""
        }
```

---

### Step 4: Update Button Content

**Location:** Lines 880-888

**Change from:**
```tsx
        ) : !applicableRule ? (
          <>
            <AlertCircle className="w-5 h-5" /> Invalid Selection
          </>
        ) : (
          <>
            <Flame className="w-5 h-5" /> Burn Selected ({selectedNFTs.length})
          </>
        )}
```

**To:**
```tsx
        ) : !applicableRule ? (
          <>
            <AlertCircle className="w-5 h-5" /> Invalid Selection
          </>
        ) : isCheckingBalance ? (
          <>
            <Loader2 className="w-5 h-5 animate-spin" /> Checking Balance...
          </>
        ) : !hasSufficientBalance ? (
          <>
            <AlertCircle className="w-5 h-5" /> Insufficient Gas Balance
          </>
        ) : (
          <>
            <Flame className="w-5 h-5" /> Burn Selected ({selectedNFTs.length})
          </>
        )}
```

---

## How It Works

### User Flow

1. **User selects NFTs**
2. **Auto-check begins** (500ms debounce)
   - Blue indicator shows: "Checking gas balance..."
   - Button disabled
3. **Check completes:**
   - ✅ **Sufficient:** Green indicator, button enabled
   - ❌ **Insufficient:** Red indicator with details, button disabled

### Example Messages

**Checking:**
```
🔵 Checking gas balance...
```

**Sufficient:**
```
✅ Sufficient balance on all chains
```

**Insufficient:**
```
❌ Insufficient balance on 2 chain(s)
```

---

## Testing

1. **Select only offchain NFTs** → No balance check (not needed)
2. **Select 1 onchain NFT** → See "Checking..." → See result
3. **Select multi-chain NFTs** → Check runs for all chains
4. **Try to burn without balance** → Button disabled with clear message

---

## Benefits

✅ **User sees balance status BEFORE clicking burn**
✅ **Clear error messages** showing which chains need funds
✅ **Button automatically disables** if insufficient balance
✅ **No wasted clicks** - user knows immediately if they can burn
✅ **Automatic checking** - runs in background, no manual action needed

---

## Implementation Status

- ✅ Hook created and working
- ✅ Hook imported in Burn.tsx
- ✅ Hook initialized with selectedNFTs
- ⏳ **TODO:** Add UI elements (Steps 1-4 above)

**Once UI elements are added, the feature is complete!**
