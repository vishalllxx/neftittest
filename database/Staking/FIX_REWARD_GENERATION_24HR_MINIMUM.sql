-- =============================================================================
-- UPDATE REWARD GENERATION - 24 HOUR MINIMUM STAKING REQUIREMENT
-- =============================================================================
-- Only generate rewards for NFTs/tokens staked for 24+ hours
-- Prevents instant rewards for newly staked assets
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '🔧 UPDATING REWARD GENERATION WITH 24-HOUR MINIMUM';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 1: Update generate_daily_staking_rewards() with 24-hour check
-- =============================================================================

DROP FUNCTION IF EXISTS generate_daily_staking_rewards();

CREATE OR REPLACE FUNCTION generate_daily_staking_rewards()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    reward_record RECORD;
    rewards_generated INTEGER := 0;
    nft_daily_total DECIMAL(18,8);
    token_daily_total DECIMAL(18,8);
    day_total DECIMAL(18,8);
    current_total_earned DECIMAL(18,8);
    total_nft_rewards DECIMAL(18,8) := 0;
    total_token_rewards DECIMAL(18,8) := 0;
    skipped_wallets INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Starting daily staking reward generation at %', NOW();
    RAISE NOTICE '📋 Rule: Only assets staked for 24+ hours will earn rewards';
    RAISE NOTICE '';
    
    -- Process rewards for each wallet with staked assets
    FOR reward_record IN (
        SELECT DISTINCT wallet_address FROM (
            SELECT wallet_address FROM staked_nfts 
            UNION 
            SELECT wallet_address FROM staked_tokens
        ) AS all_stakers
    ) LOOP
        -- ✅ Calculate NFT daily rewards (ONLY for NFTs staked 24+ hours)
        SELECT COALESCE(SUM(daily_reward), 0) 
        INTO nft_daily_total 
        FROM staked_nfts 
        WHERE wallet_address = reward_record.wallet_address
          AND staked_at <= NOW() - INTERVAL '24 hours';  -- 24-hour minimum
        
        -- ✅ Calculate Token daily rewards (ONLY for tokens staked 24+ hours)
        SELECT COALESCE(SUM(daily_reward), 0)
        INTO token_daily_total 
        FROM staked_tokens 
        WHERE wallet_address = reward_record.wallet_address
          AND staked_at <= NOW() - INTERVAL '24 hours';  -- 24-hour minimum
        
        -- Skip if no rewards to generate (nothing staked for 24+ hours)
        IF nft_daily_total = 0 AND token_daily_total = 0 THEN
            skipped_wallets := skipped_wallets + 1;
            RAISE NOTICE '  ⏳ Skipped % - no assets staked for 24+ hours yet', reward_record.wallet_address;
            CONTINUE;
        END IF;
        
        day_total := nft_daily_total + token_daily_total;
        
        -- Get current cumulative total_earned
        SELECT COALESCE(total_earned, 0)
        INTO current_total_earned
        FROM staking_rewards 
        WHERE wallet_address = reward_record.wallet_address 
        ORDER BY reward_date DESC
        LIMIT 1;
        
        -- ✅ Insert today's rewards
        INSERT INTO staking_rewards (
            wallet_address, 
            reward_date, 
            nft_earned_today,
            token_earned_today,
            total_earned,
            is_claimed,
            blockchain,
            created_at, 
            last_updated
        ) VALUES (
            reward_record.wallet_address,
            CURRENT_DATE,
            nft_daily_total,
            token_daily_total,
            current_total_earned + day_total,
            false,
            'polygon',
            NOW(), 
            NOW()
        )
        ON CONFLICT (wallet_address, reward_date) 
        DO UPDATE SET
            nft_earned_today = EXCLUDED.nft_earned_today,
            token_earned_today = EXCLUDED.token_earned_today,
            total_earned = EXCLUDED.total_earned,
            last_updated = NOW();
        
        -- Update last_reward_calculated timestamps (only for eligible assets)
        UPDATE staked_nfts 
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address
          AND staked_at <= NOW() - INTERVAL '24 hours';
        
        UPDATE staked_tokens
        SET last_reward_calculated = NOW()
        WHERE wallet_address = reward_record.wallet_address
          AND staked_at <= NOW() - INTERVAL '24 hours';
        
        total_nft_rewards := total_nft_rewards + nft_daily_total;
        total_token_rewards := total_token_rewards + token_daily_total;
        rewards_generated := rewards_generated + 1;
        
        RAISE NOTICE '  ✅ Generated rewards for %: NFT=%, Token=%', 
            reward_record.wallet_address, nft_daily_total, token_daily_total;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Daily reward generation complete';
    RAISE NOTICE '   - Wallets with rewards: %', rewards_generated;
    RAISE NOTICE '   - Wallets skipped (< 24h): %', skipped_wallets;
    RAISE NOTICE '   - Total NFT rewards: % NEFT', total_nft_rewards;
    RAISE NOTICE '   - Total Token rewards: % NEFT', total_token_rewards;
    
    RETURN json_build_object(
        'success', true,
        'wallets_processed', rewards_generated,
        'wallets_skipped', skipped_wallets,
        'total_nft_rewards', total_nft_rewards,
        'total_token_rewards', total_token_rewards,
        'timestamp', NOW()
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error generating daily rewards: %', SQLERRM;
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO postgres, authenticated, anon;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Function updated with 24-hour minimum requirement!';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- STEP 2: Test with your wallet
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '📊 Testing reward generation for your wallet...';
    RAISE NOTICE 'Wallet: 0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    RAISE NOTICE '';
END $$;

-- Check which assets are eligible (24+ hours)
SELECT 
    'NFTs Eligible for Rewards (24+ hours)' as asset_type,
    COUNT(*) as count,
    SUM(daily_reward) as total_daily_rewards,
    STRING_AGG(nft_rarity, ', ') as rarities
FROM staked_nfts 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND staked_at <= NOW() - INTERVAL '24 hours';

SELECT 
    'Tokens Eligible for Rewards (24+ hours)' as asset_type,
    COUNT(*) as count,
    SUM(daily_reward) as total_daily_rewards,
    SUM(amount) as total_staked
FROM staked_tokens 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND staked_at <= NOW() - INTERVAL '24 hours';

-- Check which assets are NOT eligible yet (< 24 hours)
SELECT 
    'NFTs NOT Eligible Yet (< 24 hours)' as asset_type,
    COUNT(*) as count,
    STRING_AGG(nft_rarity, ', ') as rarities,
    MIN(staked_at + INTERVAL '24 hours') as eligible_after
FROM staked_nfts 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND staked_at > NOW() - INTERVAL '24 hours';

SELECT 
    'Tokens NOT Eligible Yet (< 24 hours)' as asset_type,
    COUNT(*) as count,
    MIN(staked_at + INTERVAL '24 hours') as eligible_after
FROM staked_tokens 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND staked_at > NOW() - INTERVAL '24 hours';

-- =============================================================================
-- STEP 3: Generate rewards with new 24-hour rule
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '⚡ Generating rewards with 24-hour minimum rule...';
END $$;

SELECT generate_daily_staking_rewards() as generation_result;

-- =============================================================================
-- STEP 4: Check results
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📊 Checking your rewards after generation...';
END $$;

-- Your pending rewards
SELECT 
    'Your Pending Rewards' as info,
    COALESCE(SUM(nft_earned_today), 0) as pending_nft,
    COALESCE(SUM(token_earned_today), 0) as pending_token,
    COALESCE(SUM(nft_earned_today + token_earned_today), 0) as total_pending,
    COUNT(*) as reward_days
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
  AND is_claimed = false;

-- Your reward history
SELECT 
    'Your Reward History' as info,
    reward_date,
    nft_earned_today,
    token_earned_today,
    is_claimed,
    last_updated
FROM staking_rewards 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY reward_date DESC
LIMIT 5;

-- Summary function
SELECT 
    'Summary Function' as info,
    get_user_staking_summary('0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071') as summary;

-- =============================================================================
-- FINAL REPORT
-- =============================================================================

DO $$
DECLARE
    v_total_nfts INTEGER;
    v_eligible_nfts INTEGER;
    v_total_tokens DECIMAL;
    v_eligible_token_positions INTEGER;
    v_pending_rewards DECIMAL;
    v_next_eligible_time TIMESTAMP;
BEGIN
    -- Total staked
    SELECT COUNT(*) INTO v_total_nfts 
    FROM staked_nfts WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_total_tokens 
    FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071';
    
    -- Eligible (24+ hours)
    SELECT COUNT(*) INTO v_eligible_nfts 
    FROM staked_nfts 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
      AND staked_at <= NOW() - INTERVAL '24 hours';
      
    SELECT COUNT(*) INTO v_eligible_token_positions
    FROM staked_tokens 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
      AND staked_at <= NOW() - INTERVAL '24 hours';
    
    -- Pending rewards
    SELECT COALESCE(SUM(nft_earned_today + token_earned_today), 0) INTO v_pending_rewards
    FROM staking_rewards 
    WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
      AND is_claimed = false;
    
    -- Next eligible time
    SELECT MIN(staked_at + INTERVAL '24 hours') INTO v_next_eligible_time
    FROM (
        SELECT staked_at FROM staked_nfts WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
        UNION ALL
        SELECT staked_at FROM staked_tokens WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
    ) AS all_stakes
    WHERE staked_at > NOW() - INTERVAL '24 hours';
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ REWARD GENERATION WITH 24-HOUR MINIMUM';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Your Staking Status:';
    RAISE NOTICE '   • Total NFTs Staked: %', v_total_nfts;
    RAISE NOTICE '   • Total Tokens Staked: % NEFT', v_total_tokens;
    RAISE NOTICE '';
    RAISE NOTICE '⏰ 24-Hour Eligibility:';
    RAISE NOTICE '   • NFTs Eligible (24+ hours): %', v_eligible_nfts;
    RAISE NOTICE '   • NFTs Waiting (< 24 hours): %', v_total_nfts - v_eligible_nfts;
    RAISE NOTICE '   • Token Positions Eligible: %', v_eligible_token_positions;
    RAISE NOTICE '';
    
    IF v_next_eligible_time IS NOT NULL THEN
        RAISE NOTICE '⏳ Next Assets Eligible After:';
        RAISE NOTICE '   → %', v_next_eligible_time;
        RAISE NOTICE '   → In % hours', EXTRACT(EPOCH FROM (v_next_eligible_time - NOW())) / 3600;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '💰 Your Pending Rewards: % NEFT', v_pending_rewards;
    RAISE NOTICE '';
    
    IF v_pending_rewards > 0 THEN
        RAISE NOTICE '✅ SUCCESS! You have claimable rewards!';
        RAISE NOTICE '   → Refresh your staking page';
        RAISE NOTICE '   → Claim button should be enabled';
    ELSIF v_eligible_nfts = 0 AND v_eligible_token_positions = 0 THEN
        RAISE NOTICE '⏳ WAITING: No assets have reached 24-hour minimum yet';
        RAISE NOTICE '   → Assets must be staked for 24 hours before earning rewards';
        RAISE NOTICE '   → Check back after: %', v_next_eligible_time;
    ELSE
        RAISE NOTICE '⚠️  Rewards generated but not showing';
        RAISE NOTICE '   → Run this script again to regenerate';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Automatic Operation:';
    RAISE NOTICE '   • Cron job runs every 6 hours';
    RAISE NOTICE '   • Only generates rewards for assets staked 24+ hours';
    RAISE NOTICE '   • New stakes will earn rewards after 24 hours automatically';
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════════════════';
END $$;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Show all your staked assets with eligibility status
SELECT 
    'Your Staked NFTs Status' as info,
    nft_id,
    nft_rarity,
    daily_reward,
    staked_at,
    NOW() - staked_at as time_staked,
    CASE 
        WHEN staked_at <= NOW() - INTERVAL '24 hours' THEN '✅ Eligible'
        ELSE '⏳ Waiting (' || EXTRACT(HOURS FROM (staked_at + INTERVAL '24 hours' - NOW())) || 'h left)'
    END as reward_status
FROM staked_nfts 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY staked_at;

SELECT 
    'Your Staked Tokens Status' as info,
    amount,
    daily_reward,
    staked_at,
    NOW() - staked_at as time_staked,
    CASE 
        WHEN staked_at <= NOW() - INTERVAL '24 hours' THEN '✅ Eligible'
        ELSE '⏳ Waiting (' || EXTRACT(HOURS FROM (staked_at + INTERVAL '24 hours' - NOW())) || 'h left)'
    END as reward_status
FROM staked_tokens 
WHERE wallet_address = '0x5BEdd9F1415B8Eb1F669AAc68B0Fd9106b265071'
ORDER BY staked_at;
