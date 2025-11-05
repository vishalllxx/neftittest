-- ============================================================================
-- DIAGNOSE NFT DISTRIBUTION TABLE STRUCTURE
-- ============================================================================
-- This script checks the current structure of nft_cid_distribution_log table
-- to identify column mismatches causing distribution errors
-- ============================================================================

-- Check current table columns
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns
WHERE table_name = 'nft_cid_distribution_log'
ORDER BY ordinal_position;

-- Check table constraints
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'nft_cid_distribution_log'
ORDER BY tc.constraint_type, tc.constraint_name;

-- Check indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'nft_cid_distribution_log'
ORDER BY indexname;
