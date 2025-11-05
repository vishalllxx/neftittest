-- =============================================================================
-- CHECK: Balance vs Staked Amount Mismatch
-- =============================================================================
-- Problem: UI shows Available=231, Staked=370, Total=371
-- But: 231 + 370 = 601 ≠ 371
-- Real staked should be: 371 - 231 = 140
-- =============================================================================

-- 1. Check user_balances table
SELECT 
    'user_balances table' as source,
    wallet_address,
    total_neft_claimed,
    available_neft,
    staked_neft,
    (total_neft_claimed - available_neft) as calculated_staked,
    last_updated
FROM user_balances
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- 2. Check staked_tokens table (what UI displays as "Staked Amount")
SELECT 
    'staked_tokens table' as source,
    wallet_address,
    SUM(amount) as total_staked_tokens,
    COUNT(*) as staking_records
FROM staked_tokens
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
GROUP BY wallet_address;

-- 3. Check individual staking records
SELECT 
    'individual staking records' as source,
    id,
    wallet_address,
    amount,
    staked_at
FROM staked_tokens
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY staked_at DESC;

-- 4. Calculate what the CORRECT staked amount should be
SELECT 
    'CORRECT CALCULATION' as info,
    ub.total_neft_claimed as total_neft,
    ub.available_neft as available_neft,
    (ub.total_neft_claimed - ub.available_neft) as correct_staked_amount,
    COALESCE(st.db_staked, 0) as db_shows_staked,
    (COALESCE(st.db_staked, 0) - (ub.total_neft_claimed - ub.available_neft)) as difference_error
FROM user_balances ub
LEFT JOIN (
    SELECT wallet_address, SUM(amount) as db_staked
    FROM staked_tokens
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
    GROUP BY wallet_address
) st ON ub.wallet_address = st.wallet_address
WHERE ub.wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';

-- =============================================================================
-- DIAGNOSIS
-- =============================================================================
DO $$
DECLARE
    v_total DECIMAL;
    v_available DECIMAL;
    v_staked_db DECIMAL;
    v_correct_staked DECIMAL;
BEGIN
    -- Get values
    SELECT 
        total_neft_claimed,
        available_neft
    INTO v_total, v_available
    FROM user_balances
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    SELECT COALESCE(SUM(amount), 0)
    INTO v_staked_db
    FROM staked_tokens
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    v_correct_staked := v_total - v_available;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔍 BALANCE MISMATCH DIAGNOSIS';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Your Balances:';
    RAISE NOTICE '  Total NEFT: % NEFT', v_total;
    RAISE NOTICE '  Available NEFT: % NEFT', v_available;
    RAISE NOTICE '  Staked (calculated): % NEFT', v_correct_staked;
    RAISE NOTICE '';
    RAISE NOTICE 'Database Shows:';
    RAISE NOTICE '  Staked in staked_tokens table: % NEFT', v_staked_db;
    RAISE NOTICE '';
    
    IF ABS(v_staked_db - v_correct_staked) > 0.01 THEN
        RAISE NOTICE '❌ MISMATCH DETECTED!';
        RAISE NOTICE '   Difference: % NEFT', (v_staked_db - v_correct_staked);
        RAISE NOTICE '';
        RAISE NOTICE 'Possible causes:';
        RAISE NOTICE '  1. You unstaked tokens but user_balances was not updated';
        RAISE NOTICE '  2. You staked tokens but user_balances was not updated';
        RAISE NOTICE '  3. Claimed rewards were added to total but not available';
        RAISE NOTICE '';
        RAISE NOTICE '🔧 Recommended fix:';
        RAISE NOTICE '   Option 1: Update staked_tokens to match (% NEFT)', v_correct_staked;
        RAISE NOTICE '   Option 2: Update user_balances.staked_neft column';
    ELSE
        RAISE NOTICE '✅ Staked amount matches!';
    END IF;
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;
