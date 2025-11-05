-- ============================================================================
-- COMPREHENSIVE FIX: NFT Distribution System
-- ============================================================================
-- This fixes ALL mismatches between nft_cid_distribution_log table structure
-- and the distribute_unique_nft_with_chain function
-- ============================================================================

-- Step 1: Make nft_id nullable (old system field, new system doesn't use it)
-- ============================================================================
ALTER TABLE nft_cid_distribution_log 
ALTER COLUMN nft_id DROP NOT NULL;

-- Step 2: Ensure all required columns exist
-- ============================================================================
ALTER TABLE nft_cid_distribution_log
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS metadata_cid TEXT,
ADD COLUMN IF NOT EXISTS assigned_chain VARCHAR(50),
ADD COLUMN IF NOT EXISTS chain_id BIGINT,
ADD COLUMN IF NOT EXISTS chain_contract_address VARCHAR(100);

-- Step 3: Add helpful columns if they don't exist
-- ============================================================================
ALTER TABLE nft_cid_distribution_log
ADD COLUMN IF NOT EXISTS distribution_method VARCHAR(50) DEFAULT 'chain_distribution',
ADD COLUMN IF NOT EXISTS distribution_type VARCHAR(50) DEFAULT 'manual_distribution';

-- Step 4: Create indexes for performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_distribution_log_chain ON nft_cid_distribution_log(assigned_chain);
CREATE INDEX IF NOT EXISTS idx_distribution_log_wallet_chain ON nft_cid_distribution_log(wallet_address, assigned_chain);
CREATE INDEX IF NOT EXISTS idx_distribution_log_cid ON nft_cid_distribution_log(cid);

-- Step 5: Verify the fixed structure
-- ============================================================================
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'nft_cid_distribution_log'
ORDER BY ordinal_position;

-- Step 6: Create the corrected distribution function
-- ============================================================================
DROP FUNCTION IF EXISTS distribute_unique_nft_with_chain CASCADE;

CREATE OR REPLACE FUNCTION distribute_unique_nft_with_chain(
  wallet_address TEXT,
  target_rarity TEXT,
  target_chain TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  selected_nft RECORD;
  chain_config RECORD;
  final_chain TEXT;
  distribution_id INTEGER;
  generated_nft_id TEXT;
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

  -- Find available NFT (with proper enum casting)
  SELECT * INTO selected_nft
  FROM nft_cid_pools
  WHERE rarity::TEXT = target_rarity
    AND is_distributed = false
    AND (
      assigned_chain IS NULL
      OR assigned_chain = final_chain
      OR can_claim_to_any_chain = true
    )
  ORDER BY 
    CASE 
      WHEN assigned_chain = final_chain THEN 1
      WHEN assigned_chain IS NULL THEN 2
      ELSE 3
    END,
    created_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'No available ' || target_rarity || ' NFTs for ' || chain_config.chain_name
    );
  END IF;

  -- Generate unique NFT ID
  generated_nft_id := 'nft_' || target_rarity || '_' || EXTRACT(EPOCH FROM NOW())::BIGINT || '_' || (RANDOM() * 1000)::INTEGER;

  -- Update NFT with chain assignment
  UPDATE nft_cid_pools
  SET 
    is_distributed = true,
    distributed_at = NOW(),
    assigned_chain = chain_config.network,
    chain_id = chain_config.chain_id,
    chain_contract_address = chain_config.nft_contract
  WHERE id = selected_nft.id;

  -- Insert into distribution log with ALL required columns
  INSERT INTO nft_cid_distribution_log (
    wallet_address,
    cid,
    rarity,
    image_url,
    metadata_cid,
    assigned_chain,
    chain_id,
    chain_contract_address,
    distributed_at,
    nft_id,
    distribution_method
  ) VALUES (
    LOWER(wallet_address),
    selected_nft.cid,
    selected_nft.rarity,
    selected_nft.image_url,
    selected_nft.metadata_cid,
    chain_config.network,
    chain_config.chain_id,
    chain_config.nft_contract,
    NOW(),
    generated_nft_id,
    'chain_distribution'
  ) RETURNING id INTO distribution_id;

  -- Return success with NFT data
  RETURN json_build_object(
    'success', true,
    'nft_data', json_build_object(
      'id', generated_nft_id,
      'cid', selected_nft.cid,
      'name', 'NEFTIT ' || INITCAP(target_rarity),
      'description', 'Unique ' || target_rarity || ' NFT from NEFTIT platform - Assigned to ' || chain_config.chain_name,
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

-- ============================================================================
-- Step 7: Test the function
-- ============================================================================

COMMENT ON FUNCTION distribute_unique_nft_with_chain IS 'Distributes NFT to user with chain assignment - fully compatible with table structure';

-- Test query (uncomment to test):
-- SELECT distribute_unique_nft_with_chain('0x1234567890123456789012345678901234567890', 'common', 'polygon-amoy');
