-- Fix for User Deletion Foreign Key Constraint Error
-- This fixes the missing user_nft_collections table in the emergency_delete_user function

-- Updated emergency delete function that includes user_nft_collections table
CREATE OR REPLACE FUNCTION emergency_delete_user(target_wallet_address TEXT)
RETURNS TEXT AS $$
DECLARE
    total_deleted BIGINT := 0;
    table_deleted BIGINT;
    table_exists BOOLEAN;
BEGIN
    -- Delete in proper dependency order to avoid foreign key violations
    
    -- Helper function to check if table exists and has wallet_address column
    CREATE OR REPLACE FUNCTION table_has_wallet_column(table_name TEXT)
    RETURNS BOOLEAN AS $inner$
    BEGIN
        RETURN EXISTS (
            SELECT 1 
            FROM information_schema.tables t
            JOIN information_schema.columns c ON t.table_name = c.table_name
            WHERE t.table_name = table_has_wallet_column.table_name
            AND c.column_name = 'wallet_address'
            AND t.table_schema = 'public'
        );
    END;
    $inner$ LANGUAGE plpgsql;
    
    -- Level 1: Delete from referral_rewards first (it references user_referrals)
    IF table_has_wallet_column('referral_rewards') THEN
        BEGIN
            DELETE FROM referral_rewards WHERE referrer_wallet = target_wallet_address;
            GET DIAGNOSTICS table_deleted = ROW_COUNT;
            total_deleted := total_deleted + table_deleted;
            IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from referral_rewards (referrer_wallet)', table_deleted; END IF;
        EXCEPTION
            WHEN undefined_column THEN
                -- Try wallet_address column
                BEGIN
                    DELETE FROM referral_rewards WHERE wallet_address = target_wallet_address;
                    GET DIAGNOSTICS table_deleted = ROW_COUNT;
                    total_deleted := total_deleted + table_deleted;
                    IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from referral_rewards (wallet_address)', table_deleted; END IF;
                EXCEPTION
                    WHEN undefined_column THEN
                        RAISE NOTICE 'Skipping referral_rewards - no matching column found';
                END;
        END;
    ELSE
        RAISE NOTICE 'Skipping referral_rewards - table does not exist';
    END IF;
    
    -- Level 2: Delete from tables that depend on user_referrals
    IF table_has_wallet_column('user_referrals') THEN
        DELETE FROM user_referrals WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_referrals', table_deleted; END IF;
    ELSE
        RAISE NOTICE 'Skipping user_referrals - table does not exist';
    END IF;
    
    -- Level 3: Delete from all other child tables (only if they exist)
    IF table_has_wallet_column('user_activity_stats') THEN
        DELETE FROM user_activity_stats WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_activity_stats', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_ipfs_mappings') THEN
        DELETE FROM user_ipfs_mappings WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_ipfs_mappings', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('nft_claims') THEN
        DELETE FROM nft_claims WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from nft_claims', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('campaign_reward_claims') THEN
        DELETE FROM campaign_reward_claims WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from campaign_reward_claims', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_burn_progress') THEN
        DELETE FROM user_burn_progress WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_burn_progress', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_burn_chances_earned') THEN
        DELETE FROM user_burn_chances_earned WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_burn_chances_earned', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('staked_nfts') THEN
        DELETE FROM staked_nfts WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from staked_nfts', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_participations') THEN
        DELETE FROM user_participations WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_participations', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_task_completions') THEN
        DELETE FROM user_task_completions WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_task_completions', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('staking_rewards') THEN
        DELETE FROM staking_rewards WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from staking_rewards', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_activities') THEN
        DELETE FROM user_activities WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_activities', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('nft_collections') THEN
        DELETE FROM nft_collections WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from nft_collections', table_deleted; END IF;
    END IF;
    
    -- *** CRITICAL FIX: Add user_nft_collections table deletion ***
    IF table_has_wallet_column('user_nft_collections') THEN
        DELETE FROM user_nft_collections WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_nft_collections', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('staking_history') THEN
        DELETE FROM staking_history WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from staking_history', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_balances') THEN
        DELETE FROM user_balances WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_balances', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_streaks') THEN
        DELETE FROM user_streaks WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_streaks', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('daily_claims') THEN
        DELETE FROM daily_claims WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from daily_claims', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_achievements') THEN
        DELETE FROM user_achievements WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_achievements', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_achievement_progress') THEN
        DELETE FROM user_achievement_progress WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_achievement_progress', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('achievement_balance_audit') THEN
        DELETE FROM achievement_balance_audit WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from achievement_balance_audit', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('nft_distributions') THEN
        DELETE FROM nft_distributions WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from nft_distributions', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('staked_tokens') THEN
        DELETE FROM staked_tokens WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from staked_tokens', table_deleted; END IF;
    END IF;
    
    IF table_has_wallet_column('user_participation_stats') THEN
        DELETE FROM user_participation_stats WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from user_participation_stats', table_deleted; END IF;
    END IF;
    
    -- Also check for nft_cid_distribution_log which is referenced by user_nft_collections
    IF table_has_wallet_column('nft_cid_distribution_log') THEN
        DELETE FROM nft_cid_distribution_log WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from nft_cid_distribution_log', table_deleted; END IF;
    END IF;
    
    -- Also check for nft_burns table
    IF table_has_wallet_column('nft_burns') THEN
        DELETE FROM nft_burns WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from nft_burns', table_deleted; END IF;
    END IF;
    
    -- Also check for burn_transactions table
    IF table_has_wallet_column('burn_transactions') THEN
        DELETE FROM burn_transactions WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from burn_transactions', table_deleted; END IF;
    END IF;
    
    -- Also check for referrals table
    IF table_has_wallet_column('referrals') THEN
        -- Delete as referrer
        DELETE FROM referrals WHERE referrer_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from referrals (as referrer)', table_deleted; END IF;
        
        -- Delete as referee (if wallet_address column exists)
        BEGIN
            DELETE FROM referrals WHERE wallet_address = target_wallet_address;
            GET DIAGNOSTICS table_deleted = ROW_COUNT;
            total_deleted := total_deleted + table_deleted;
            IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from referrals (as referee)', table_deleted; END IF;
        EXCEPTION
            WHEN undefined_column THEN
                RAISE NOTICE 'Skipping referrals wallet_address column - does not exist';
        END;
    END IF;
    
    -- Finally delete from users table
    IF table_has_wallet_column('users') THEN
        DELETE FROM users WHERE wallet_address = target_wallet_address;
        GET DIAGNOSTICS table_deleted = ROW_COUNT;
        total_deleted := total_deleted + table_deleted;
        IF table_deleted > 0 THEN RAISE NOTICE 'Deleted % records from users', table_deleted; END IF;
    END IF;
    
    -- Clean up helper function
    DROP FUNCTION IF EXISTS table_has_wallet_column(TEXT);
    
    RETURN format('Successfully deleted user and %s related records', total_deleted);
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION emergency_delete_user(TEXT) TO authenticated, anon, service_role;

-- Test the function (uncomment to test with a specific wallet address)
-- SELECT emergency_delete_user('test_wallet_address_here');

-- Usage instructions:
SELECT 'FIXED emergency_delete_user function created!' as status;
SELECT 'Now includes user_nft_collections and other missing tables' as info;
SELECT 'Usage: SELECT emergency_delete_user(''wallet_address_here'');' as usage;
