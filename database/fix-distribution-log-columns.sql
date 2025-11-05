-- ============================================================================
-- FIX: Add missing columns to nft_cid_distribution_log table
-- ============================================================================
-- This adds image_url and metadata_cid columns that are referenced by the
-- distribute_unique_nft_with_chain function
-- ============================================================================

-- Add missing columns to distribution log
ALTER TABLE nft_cid_distribution_log
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS metadata_cid TEXT,
ADD COLUMN IF NOT EXISTS assigned_chain VARCHAR(50),
ADD COLUMN IF NOT EXISTS chain_id BIGINT,
ADD COLUMN IF NOT EXISTS chain_contract_address VARCHAR(100);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_distribution_log_chain ON nft_cid_distribution_log(assigned_chain);
CREATE INDEX IF NOT EXISTS idx_distribution_log_wallet_chain ON nft_cid_distribution_log(wallet_address, assigned_chain);

-- Verify the table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'nft_cid_distribution_log'
ORDER BY ordinal_position;

-- ============================================================================
-- Expected columns after this migration:
-- ============================================================================
-- id (uuid)
-- wallet_address (text)
-- cid (text)
-- rarity (nft_rarity or text)
-- image_url (text)                    <- Added
-- metadata_cid (text)                 <- Added
-- assigned_chain (varchar)            <- Added
-- chain_id (bigint)                   <- Added
-- chain_contract_address (varchar)    <- Added
-- distributed_at (timestamp)
-- created_at (timestamp)
