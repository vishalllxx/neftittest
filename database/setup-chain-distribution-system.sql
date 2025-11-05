-- ============================================================================
-- NEFTIT CHAIN-SPECIFIC NFT DISTRIBUTION SYSTEM
-- ============================================================================
-- Purpose: Setup database for flexible chain assignment during distribution
-- Chain assignment happens when NFT is distributed, NOT during IPFS upload
-- ============================================================================

-- Step 0: Drop existing functions if they exist
-- ============================================================================
-- This prevents "cannot change return type" errors
-- Drop all variations of the functions using CASCADE
DROP FUNCTION IF EXISTS get_available_cid_counts_by_chain() CASCADE;
DROP FUNCTION IF EXISTS distribute_unique_nft_with_chain CASCADE;
DROP FUNCTION IF EXISTS get_supported_chains() CASCADE;
DROP FUNCTION IF EXISTS clear_all_cid_pools() CASCADE;

-- Step 1: Create supported_chains table
-- ============================================================================
CREATE TABLE IF NOT EXISTS supported_chains (
  id SERIAL PRIMARY KEY,
  network TEXT UNIQUE NOT NULL,
  chain_id BIGINT NOT NULL,
  chain_name TEXT NOT NULL,
  nft_contract TEXT NOT NULL,
  staking_contract TEXT,
  rpc_url TEXT,
  explorer_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_supported_chains_network ON supported_chains(network);
CREATE INDEX IF NOT EXISTS idx_supported_chains_active ON supported_chains(is_active);

-- Step 2: Insert chain configurations
-- ============================================================================
INSERT INTO supported_chains (network, chain_id, chain_name, nft_contract, staking_contract, rpc_url, explorer_url) VALUES
('polygon-amoy', 80002, 'Polygon Amoy Testnet', 
 '0x5Bb23220cC12585264fCd144C448eF222c8572A2', 
 '0x1F2Dbf590b1c4C96c1ddb4FF55002Dbb33DA294e',
 'https://rpc-amoy.polygon.technology',
 'https://amoy.polygonscan.com'),

('sepolia', 11155111, 'Ethereum Sepolia', 
 '0xedE55c384D620dD9a06d39fA632b2B55f29Bd387', 
 '0x637B5CbfBFd074Fe468e2B976b780862448F984C',
 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
 'https://sepolia.etherscan.io'),

('bsc-testnet', 97, 'BNB Smart Chain Testnet', 
 '0xfaAA35A41f070B7408740Fefff0635fD5B66398b', 
 '0x1FAe00647ff1931Ab9d234E685EAf5211bed12b7',
 'https://data-seed-prebsc-1-s1.binance.org:8545',
 'https://testnet.bscscan.com'),

('avalanche-fuji', 43113, 'Avalanche Fuji Testnet', 
 '0x7a85EE8944EC9d15528c7517D1FD2A173f552F08', 
 '0x95F2B1d375532690a78f152E4c90F4a6196fB8Df',
 'https://api.avax-test.network/ext/bc/C/rpc',
 'https://testnet.snowtrace.io'),

('arbitrum-sepolia', 421614, 'Arbitrum Sepolia', 
 '0x71EC87B1aFBe18255e8c415c3d84c9369719de21', 
 '0x5B17525Db3B6811F36a0e301d0Ff286b44b51147',
 'https://sepolia-rollup.arbitrum.io/rpc',
 'https://sepolia.arbiscan.io'),

('optimism-sepolia', 11155420, 'Optimism Sepolia', 
 '0x68C3734b65e3b2f7858123ccb5Bfc5fd7cC1D733', 
 '0x37Fdb126989C1c355b93f0155FEe0CbD0e892AF8',
 'https://sepolia.optimism.io',
 'https://sepolia-optimism.etherscan.io'),

('base-sepolia', 84532, 'Base Sepolia', 
 '0x10ca82E3F31459f7301BDE2ca8Cf93CCA4113705', 
 '0xB250CD56aDB08cd30aBC275b9E20978A92bC4dd1',
 'https://sepolia.base.org',
 'https://sepolia.basescan.org')

ON CONFLICT (network) DO UPDATE SET
  chain_id = EXCLUDED.chain_id,
  chain_name = EXCLUDED.chain_name,
  nft_contract = EXCLUDED.nft_contract,
  staking_contract = EXCLUDED.staking_contract,
  rpc_url = EXCLUDED.rpc_url,
  explorer_url = EXCLUDED.explorer_url,
  updated_at = NOW();

-- Step 3: Update nft_cid_pools table structure (if needed)
-- ============================================================================
-- Make chain fields nullable since they're assigned during distribution
ALTER TABLE nft_cid_pools 
  ALTER COLUMN assigned_chain DROP NOT NULL,
  ALTER COLUMN chain_id DROP NOT NULL,
  ALTER COLUMN chain_contract_address DROP NOT NULL;

-- Add can_claim_to_any_chain flag if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'nft_cid_pools' 
    AND column_name = 'can_claim_to_any_chain'
  ) THEN
    ALTER TABLE nft_cid_pools 
    ADD COLUMN can_claim_to_any_chain BOOLEAN DEFAULT true;
  END IF;
END $$;

-- Step 4: Fix foreign key constraint for cascade delete
-- ============================================================================
ALTER TABLE nft_cid_distribution_log
DROP CONSTRAINT IF EXISTS fk_distribution_log_cid_pools;

ALTER TABLE nft_cid_distribution_log
ADD CONSTRAINT fk_distribution_log_cid_pools
FOREIGN KEY (cid) REFERENCES nft_cid_pools(cid)
ON DELETE CASCADE;  -- Auto-delete distributions when pool cleared

-- Step 5: Create/Update distribution function with chain assignment
-- ============================================================================
CREATE OR REPLACE FUNCTION distribute_unique_nft_with_chain(
  wallet_address TEXT,
  target_rarity TEXT,
  target_chain TEXT DEFAULT NULL  -- Chain selected at distribution time
)
RETURNS JSON AS $$
DECLARE
  selected_nft RECORD;
  chain_config RECORD;
  final_chain TEXT;
  distribution_id UUID;
BEGIN
  -- Validate wallet address
  IF wallet_address IS NULL OR wallet_address = '' THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'Invalid wallet address'
    );
  END IF;

  -- Determine final chain (use target_chain or default to polygon-amoy)
  final_chain := COALESCE(target_chain, 'polygon-amoy');

  -- Get chain configuration
  SELECT * INTO chain_config
  FROM supported_chains
  WHERE network = final_chain
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'Invalid or inactive chain: ' || final_chain
    );
  END IF;

  -- Find available NFT (either unassigned or matching requested chain)
  SELECT * INTO selected_nft
  FROM nft_cid_pools
  WHERE rarity::TEXT = target_rarity
    AND is_distributed = false
    AND (
      assigned_chain IS NULL  -- Unassigned NFTs
      OR assigned_chain = final_chain  -- Or already assigned to requested chain
      OR can_claim_to_any_chain = true  -- Or flexible NFTs
    )
  ORDER BY 
    CASE 
      WHEN assigned_chain = final_chain THEN 1  -- Prefer exact match
      WHEN assigned_chain IS NULL THEN 2        -- Then unassigned
      ELSE 3                                     -- Finally flexible
    END,
    created_at ASC  -- Oldest first
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'No available ' || target_rarity || ' NFTs for ' || chain_config.chain_name
    );
  END IF;

  -- Update NFT with chain assignment (happens NOW during distribution)
  UPDATE nft_cid_pools
  SET 
    is_distributed = true,
    distributed_at = NOW(),
    assigned_chain = chain_config.network,
    chain_id = chain_config.chain_id,
    chain_contract_address = chain_config.nft_contract
  WHERE id = selected_nft.id;

  -- Insert into distribution log
  INSERT INTO nft_cid_distribution_log (
    wallet_address,
    cid,
    rarity,
    image_url,
    metadata_cid,
    assigned_chain,
    chain_id,
    chain_contract_address,
    distributed_at
  ) VALUES (
    LOWER(wallet_address),
    selected_nft.cid,
    selected_nft.rarity,
    selected_nft.image_url,
    selected_nft.metadata_cid,
    chain_config.network,
    chain_config.chain_id,
    chain_config.nft_contract,
    NOW()
  ) RETURNING id INTO distribution_id;

  -- Return success with NFT data
  RETURN json_build_object(
    'success', true,
    'nft_data', json_build_object(
      'id', selected_nft.id,
      'cid', selected_nft.cid,
      'name', 'NEFTIT ' || INITCAP(selected_nft.rarity),
      'description', 'Unique ' || selected_nft.rarity || ' NFT from NEFTIT platform - Assigned to ' || chain_config.chain_name,
      'rarity', selected_nft.rarity,
      'image', selected_nft.image_url,
      'metadata_cid', selected_nft.metadata_cid,
      'assigned_chain', chain_config.network,
      'chain_id', chain_config.chain_id,
      'chain_name', chain_config.chain_name,
      'chain_contract_address', chain_config.nft_contract,
      'distribution_id', distribution_id,
      'distributed_at', NOW()
    )
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Distribution failed: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create function to get available counts by chain
-- ============================================================================
CREATE OR REPLACE FUNCTION get_available_cid_counts_by_chain()
RETURNS TABLE (
  rarity TEXT,
  assigned_chain TEXT,
  total_count BIGINT,
  available_count BIGINT,
  distributed_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ncp.rarity::TEXT,
    COALESCE(ncp.assigned_chain, 'unassigned') as assigned_chain,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE ncp.is_distributed = false) as available_count,
    COUNT(*) FILTER (WHERE ncp.is_distributed = true) as distributed_count
  FROM nft_cid_pools ncp
  GROUP BY ncp.rarity::TEXT, COALESCE(ncp.assigned_chain, 'unassigned')
  ORDER BY 
    CASE ncp.rarity::TEXT
      WHEN 'common' THEN 1
      WHEN 'rare' THEN 2
      WHEN 'legendary' THEN 3
      WHEN 'platinum' THEN 4
      WHEN 'silver' THEN 5
      WHEN 'gold' THEN 6
      ELSE 7
    END,
    assigned_chain;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create function to get all supported chains
-- ============================================================================
CREATE OR REPLACE FUNCTION get_supported_chains()
RETURNS TABLE (
  network TEXT,
  chain_id BIGINT,
  chain_name TEXT,
  nft_contract TEXT,
  staking_contract TEXT,
  is_active BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sc.network,
    sc.chain_id,
    sc.chain_name,
    sc.nft_contract,
    sc.staking_contract,
    sc.is_active
  FROM supported_chains sc
  WHERE sc.is_active = true
  ORDER BY sc.chain_id;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create helper function to clear all pools
-- ============================================================================
CREATE OR REPLACE FUNCTION clear_all_cid_pools()
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER  -- Bypass RLS policies
AS $$
DECLARE
  deleted_distributions BIGINT;
  deleted_pools BIGINT;
BEGIN
  -- Delete distribution log first (cascade will handle this but being explicit)
  DELETE FROM nft_cid_distribution_log WHERE true;
  GET DIAGNOSTICS deleted_distributions = ROW_COUNT;

  -- Delete pool entries
  DELETE FROM nft_cid_pools WHERE true;
  GET DIAGNOSTICS deleted_pools = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'deleted_distributions', deleted_distributions,
    'deleted_pools', deleted_pools,
    'message', 'Successfully cleared ' || deleted_pools || ' NFTs and ' || deleted_distributions || ' distributions'
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Failed to clear pools: ' || SQLERRM
    );
END;
$$;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check supported chains
-- SELECT * FROM get_supported_chains();

-- Check available NFT counts by chain
-- SELECT * FROM get_available_cid_counts_by_chain();

-- Test distribution
-- SELECT distribute_unique_nft_with_chain('0x1234567890123456789012345678901234567890', 'common', 'polygon-amoy');

-- Clear all pools
-- SELECT clear_all_cid_pools();

COMMENT ON TABLE supported_chains IS 'Stores configuration for all supported blockchain networks';
COMMENT ON FUNCTION distribute_unique_nft_with_chain IS 'Distributes NFT to user and assigns chain during distribution';
COMMENT ON FUNCTION get_available_cid_counts_by_chain IS 'Returns NFT availability statistics by chain';
COMMENT ON FUNCTION get_supported_chains IS 'Returns list of active supported chains';
COMMENT ON FUNCTION clear_all_cid_pools IS 'Clears all NFT pools and distribution logs';
