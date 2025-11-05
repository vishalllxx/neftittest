-- ============================================================================
-- CORRECT REWARD GENERATION FUNCTION FOR YOUR ACTUAL SCHEMA
-- ============================================================================
-- This matches your actual staking_rewards table schema:
-- - reward_type (TEXT): 'nft_staking' or 'token_staking'
-- - reward_amount (DECIMAL): Single column for amount
-- - source_id (UUID): References staked_nfts.id or staked_tokens.id
-- - is_claimed (BOOLEAN): Claim status
-- ============================================================================

-- Drop existing incorrect function
DROP FUNCTION IF EXISTS generate_daily_staking_rewards();

-- Create correct function that matches YOUR actual schema
CREATE OR REPLACE FUNCTION generate_daily_staking_rewards()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nft_record RECORD;
    token_record RECORD;
    rewards_generated INTEGER := 0;
    total_nft_rewards DECIMAL(18,8) := 0;
    total_token_rewards DECIMAL(18,8) := 0;
    days_to_generate INTEGER;
    current_gen_date DATE;
    last_reward_date DATE;
BEGIN
    RAISE NOTICE '🔄 Starting reward generation at %', NOW();
    RAISE NOTICE '📋 Using correct schema: reward_type, reward_amount, source_id';
    
    -- ============================================================================
    -- PART 1: Generate NFT Staking Rewards
    -- ============================================================================
    FOR nft_record IN (
        SELECT 
            id,
            wallet_address,
            nft_id,
            daily_reward,
            staked_at,
            last_reward_calculated
        FROM staked_nfts
    ) LOOP
        -- Get last reward date for this specific NFT
        SELECT MAX(reward_date) INTO last_reward_date
        FROM staking_rewards
        WHERE wallet_address = nft_record.wallet_address
          AND reward_type = 'nft_staking'
          AND source_id = nft_record.id;
        
        -- Determine start date for reward generation
        IF last_reward_date IS NULL THEN
            -- No rewards yet, start from staking date
            current_gen_date := DATE(nft_record.staked_at);
        ELSE
            -- Start from day after last reward
            current_gen_date := last_reward_date + INTERVAL '1 day';
        END IF;
        
        -- Generate rewards for each missing day up to TODAY
        WHILE current_gen_date <= CURRENT_DATE LOOP
            INSERT INTO staking_rewards (
                wallet_address,
                reward_type,
                source_id,
                reward_amount,
                reward_date,
                is_claimed,
                created_at
            ) VALUES (
                nft_record.wallet_address,
                'nft_staking',
                nft_record.id,
                nft_record.daily_reward,
                current_gen_date,
                FALSE,
                NOW()
            )
            ON CONFLICT (wallet_address, reward_type, source_id, reward_date) 
            DO NOTHING; -- Skip if already exists
            
            total_nft_rewards := total_nft_rewards + nft_record.daily_reward;
            current_gen_date := current_gen_date + INTERVAL '1 day';
        END LOOP;
        
        -- Update last_reward_calculated
        UPDATE staked_nfts
        SET last_reward_calculated = NOW()
        WHERE id = nft_record.id;
        
        rewards_generated := rewards_generated + 1;
    END LOOP;
    
    RAISE NOTICE '✅ Generated NFT rewards: % NEFT for % NFTs', total_nft_rewards, rewards_generated;
    
    -- ============================================================================
    -- PART 2: Generate Token Staking Rewards
    -- ============================================================================
    rewards_generated := 0;
    
    FOR token_record IN (
        SELECT 
            id,
            wallet_address,
            amount,
            daily_reward,
            staked_at,
            last_reward_calculated
        FROM staked_tokens
    ) LOOP
        -- Get last reward date for this specific token stake
        SELECT MAX(reward_date) INTO last_reward_date
        FROM staking_rewards
        WHERE wallet_address = token_record.wallet_address
          AND reward_type = 'token_staking'
          AND source_id = token_record.id;
        
        -- Determine start date for reward generation
        IF last_reward_date IS NULL THEN
            -- No rewards yet, start from staking date
            current_gen_date := DATE(token_record.staked_at);
        ELSE
            -- Start from day after last reward
            current_gen_date := last_reward_date + INTERVAL '1 day';
        END IF;
        
        -- Generate rewards for each missing day up to TODAY
        WHILE current_gen_date <= CURRENT_DATE LOOP
            INSERT INTO staking_rewards (
                wallet_address,
                reward_type,
                source_id,
                reward_amount,
                reward_date,
                is_claimed,
                created_at
            ) VALUES (
                token_record.wallet_address,
                'token_staking',
                token_record.id,
                token_record.daily_reward,
                current_gen_date,
                FALSE,
                NOW()
            )
            ON CONFLICT (wallet_address, reward_type, source_id, reward_date) 
            DO NOTHING; -- Skip if already exists
            
            total_token_rewards := total_token_rewards + token_record.daily_reward;
            current_gen_date := current_gen_date + INTERVAL '1 day';
        END LOOP;
        
        -- Update last_reward_calculated
        UPDATE staked_tokens
        SET last_reward_calculated = NOW()
        WHERE id = token_record.id;
        
        rewards_generated := rewards_generated + 1;
    END LOOP;
    
    RAISE NOTICE '✅ Generated Token rewards: % NEFT for % stakes', total_token_rewards, rewards_generated;
    
    RAISE NOTICE '🎯 Total rewards generated: % NEFT', total_nft_rewards + total_token_rewards;
    
    RETURN json_build_object(
        'success', true,
        'total_nft_rewards', total_nft_rewards,
        'total_token_rewards', total_token_rewards,
        'total_rewards', total_nft_rewards + total_token_rewards,
        'timestamp', NOW()
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ Error generating rewards: %', SQLERRM;
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_daily_staking_rewards() TO authenticated, anon, public;

-- ============================================================================
-- VERIFICATION & TEST
-- ============================================================================
DO $$
DECLARE
    result JSON;
    nft_count INTEGER;
    token_count INTEGER;
BEGIN
    -- Count staked assets
    SELECT COUNT(*) INTO nft_count FROM staked_nfts;
    SELECT COUNT(*) INTO token_count FROM staked_tokens;
    
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '🔧 CORRECTED REWARD GENERATION FUNCTION';
    RAISE NOTICE '═══════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Schema Compatibility:';
    RAISE NOTICE '   ✅ Uses reward_type (nft_staking/token_staking)';
    RAISE NOTICE '   ✅ Uses reward_amount (single column)';
    RAISE NOTICE '   ✅ Uses source_id (references staked_nfts/tokens)';
    RAISE NOTICE '   ✅ Uses is_claimed (boolean)';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Features:';
    RAISE NOTICE '   ✅ Generates rewards for EACH missing day since staking';
    RAISE NOTICE '   ✅ Processes NFTs individually (separate records)';
    RAISE NOTICE '   ✅ Processes token stakes individually';
    RAISE NOTICE '   ✅ Prevents duplicates with ON CONFLICT';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Current Staked Assets:';
    RAISE NOTICE '   - Staked NFTs: %', nft_count;
    RAISE NOTICE '   - Staked Token Positions: %', token_count;
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Running first generation...';
    RAISE NOTICE '';
    
    -- Run the function
    result := generate_daily_staking_rewards();
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Generation Complete!';
    RAISE NOTICE '   Result: %', result;
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Verify with:';
    RAISE NOTICE '   SELECT wallet_address, reward_type, COUNT(*) as days, SUM(reward_amount) as total';
    RAISE NOTICE '   FROM staking_rewards';
    RAISE NOTICE '   GROUP BY wallet_address, reward_type;';
    RAISE NOTICE '';
END $$;
