-- ============================================================================
-- CHAIN-SPECIFIC NFT DISTRIBUTION SYSTEM
-- ============================================================================
-- This migration adds blockchain chain assignment to NFT CID pools
-- allowing NFTs to be assigned to specific chains (Polygon, Sepolia, BSC, etc.)
-- and only claimable to their designated chain
-- ============================================================================

-- Step 1: Add chain-related columns to nft_cid_pools table
ALTER TABLE nft_cid_pools 
ADD COLUMN IF NOT EXISTS assigned_chain VARCHAR(50),
ADD COLUMN IF NOT EXISTS chain_id INTEGER,
ADD COLUMN IF NOT EXISTS chain_contract_address VARCHAR(100),
ADD COLUMN IF NOT EXISTS can_claim_to_any_chain BOOLEAN DEFAULT FALSE;

-- Create index for chain lookups
CREATE INDEX IF NOT EXISTS idx_nft_cid_pools_chain ON nft_cid_pools(assigned_chain);
CREATE INDEX IF NOT EXISTS idx_nft_cid_pools_chain_rarity ON nft_cid_pools(assigned_chain, rarity, is_distributed);

-- Step 2: Add chain info to distribution log
ALTER TABLE nft_cid_distribution_log 
ADD COLUMN IF NOT EXISTS assigned_chain VARCHAR(50),
ADD COLUMN IF NOT EXISTS claimed_chain VARCHAR(50),
ADD COLUMN IF NOT EXISTS claimed_contract_address VARCHAR(100),
ADD COLUMN IF NOT EXISTS claimed_token_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS claimed_transaction_hash VARCHAR(100),
ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMP WITH TIME ZONE;

-- Create indexes for chain tracking
CREATE INDEX IF NOT EXISTS idx_distribution_log_assigned_chain ON nft_cid_distribution_log(assigned_chain);
CREATE INDEX IF NOT EXISTS idx_distribution_log_claimed_chain ON nft_cid_distribution_log(claimed_chain);

-- Step 3: Function to get available CIDs for specific chain and rarity
CREATE OR REPLACE FUNCTION get_next_available_cid_by_chain(
    target_rarity VARCHAR(20),
    target_chain VARCHAR(50)
) RETURNS TABLE(
    cid VARCHAR(100),
    image_url TEXT,
    metadata_cid VARCHAR(100),
    pool_id INTEGER,
    assigned_chain VARCHAR(50),
    chain_id INTEGER,
    chain_contract_address VARCHAR(100)
) 
SECURITY DEFINER
AS $$
BEGIN
    -- Get the next available CID for the specified rarity and chain
    RETURN QUERY
    SELECT 
        p.cid,
        p.image_url,
        p.metadata_cid,
        p.id as pool_id,
        p.assigned_chain,
        p.chain_id,
        p.chain_contract_address
    FROM nft_cid_pools p
    WHERE p.rarity = target_rarity::nft_rarity 
    AND p.is_distributed = FALSE
    AND p.assigned_chain = target_chain
    ORDER BY p.created_at DESC, p.id DESC 
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Function to distribute NFT with chain assignment
CREATE OR REPLACE FUNCTION distribute_unique_nft_with_chain(
    wallet_address VARCHAR(100),
    target_rarity VARCHAR(20),
    target_chain VARCHAR(50) DEFAULT NULL
) RETURNS JSON
SECURITY DEFINER
AS $$
DECLARE
    available_cid RECORD;
    nft_id VARCHAR(50);
    distribution_result JSON;
    selected_chain VARCHAR(50);
BEGIN
    -- Generate unique NFT ID
    nft_id := 'nft_' || target_rarity || '_' || EXTRACT(EPOCH FROM NOW())::BIGINT || '_' || (RANDOM() * 1000)::INTEGER;
    
    -- If no chain specified, get next available from any chain
    IF target_chain IS NULL THEN
        SELECT * INTO available_cid 
        FROM get_next_available_cid(target_rarity);
        
        selected_chain := available_cid.assigned_chain;
    ELSE
        -- Get CID for specific chain
        SELECT * INTO available_cid 
        FROM get_next_available_cid_by_chain(target_rarity, target_chain);
        
        selected_chain := target_chain;
    END IF;
    
    -- Check if CID is available
    IF available_cid.cid IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'No available CIDs for rarity: ' || target_rarity || 
                     CASE WHEN target_chain IS NOT NULL 
                          THEN ' and chain: ' || target_chain 
                          ELSE '' 
                     END
        );
    END IF;
    
    -- Mark CID as distributed
    UPDATE nft_cid_pools 
    SET 
        is_distributed = TRUE,
        distributed_to_wallet = wallet_address,
        distributed_at = NOW()
    WHERE cid = available_cid.cid
    AND is_distributed = FALSE;
    
    -- Log the distribution with chain info
    INSERT INTO nft_cid_distribution_log (
        wallet_address,
        rarity,
        cid,
        nft_id,
        distributed_at,
        distribution_method,
        assigned_chain
    ) VALUES (
        wallet_address,
        target_rarity,
        available_cid.cid,
        nft_id,
        NOW(),
        'unique_distribution_with_chain',
        selected_chain
    );
    
    -- Return complete NFT data with chain info
    RETURN json_build_object(
        'success', true,
        'nft_data', json_build_object(
            'id', nft_id,
            'name', 'NEFTIT ' || INITCAP(target_rarity) || ' NFT',
            'description', 'Unique ' || target_rarity || ' NFT from NEFTIT platform - Assigned to ' || COALESCE(selected_chain, 'any chain'),
            'image', available_cid.image_url,
            'rarity', target_rarity,
            'cid', available_cid.cid,
            'metadata_cid', available_cid.metadata_cid,
            'assigned_chain', selected_chain,
            'chain_id', available_cid.chain_id,
            'chain_contract_address', available_cid.chain_contract_address,
            'can_claim_to_any_chain', available_cid.can_claim_to_any_chain,
            'attributes', json_build_array(
                json_build_object('trait_type', 'Rarity', 'value', INITCAP(target_rarity)),
                json_build_object('trait_type', 'Platform', 'value', 'NEFTIT'),
                json_build_object('trait_type', 'Unique ID', 'value', nft_id),
                json_build_object('trait_type', 'Assigned Chain', 'value', COALESCE(selected_chain, 'Multi-Chain'))
            )
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 5: Function to get available CID counts by chain and rarity
CREATE OR REPLACE FUNCTION get_available_cid_counts_by_chain()
RETURNS TABLE(
    rarity nft_rarity,
    assigned_chain VARCHAR(50),
    total_count BIGINT,
    available_count BIGINT,
    distributed_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.rarity,
        COALESCE(p.assigned_chain, 'unassigned') as assigned_chain,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE p.is_distributed = false) as available_count,
        COUNT(*) FILTER (WHERE p.is_distributed = true) as distributed_count
    FROM nft_cid_pools p
    GROUP BY p.rarity, p.assigned_chain
    ORDER BY p.rarity, p.assigned_chain;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Function to validate if NFT can be claimed to specific chain
CREATE OR REPLACE FUNCTION can_claim_nft_to_chain(
    nft_cid VARCHAR(100),
    target_claim_chain VARCHAR(50)
) RETURNS JSON
SECURITY DEFINER
AS $$
DECLARE
    nft_record RECORD;
BEGIN
    -- Get NFT details
    SELECT 
        assigned_chain,
        can_claim_to_any_chain,
        is_distributed,
        distributed_to_wallet
    INTO nft_record
    FROM nft_cid_pools
    WHERE cid = nft_cid;
    
    -- Check if NFT exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'can_claim', false,
            'error', 'NFT not found'
        );
    END IF;
    
    -- Check if NFT is distributed
    IF NOT nft_record.is_distributed THEN
        RETURN json_build_object(
            'can_claim', false,
            'error', 'NFT not yet distributed to any user'
        );
    END IF;
    
    -- Check if can claim to any chain
    IF nft_record.can_claim_to_any_chain THEN
        RETURN json_build_object(
            'can_claim', true,
            'message', 'NFT can be claimed to any supported chain',
            'assigned_chain', nft_record.assigned_chain,
            'target_chain', target_claim_chain
        );
    END IF;
    
    -- Check if target chain matches assigned chain
    IF nft_record.assigned_chain = target_claim_chain THEN
        RETURN json_build_object(
            'can_claim', true,
            'message', 'NFT can be claimed to assigned chain',
            'assigned_chain', nft_record.assigned_chain,
            'target_chain', target_claim_chain
        );
    ELSE
        RETURN json_build_object(
            'can_claim', false,
            'error', 'NFT can only be claimed to ' || nft_record.assigned_chain || ', not ' || target_claim_chain,
            'assigned_chain', nft_record.assigned_chain,
            'target_chain', target_claim_chain
        );
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'can_claim', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 7: Function to record NFT claim to blockchain
CREATE OR REPLACE FUNCTION record_nft_claim_to_chain(
    nft_cid VARCHAR(100),
    claimed_chain VARCHAR(50),
    contract_address VARCHAR(100),
    token_id VARCHAR(50),
    transaction_hash VARCHAR(100)
) RETURNS JSON
SECURITY DEFINER
AS $$
DECLARE
    validation_result JSON;
BEGIN
    -- Validate if NFT can be claimed to this chain
    SELECT can_claim_nft_to_chain(nft_cid, claimed_chain) INTO validation_result;
    
    IF NOT (validation_result->>'can_claim')::BOOLEAN THEN
        RETURN validation_result;
    END IF;
    
    -- Update distribution log
    UPDATE nft_cid_distribution_log
    SET 
        claimed_chain = record_nft_claim_to_chain.claimed_chain,
        claimed_contract_address = record_nft_claim_to_chain.contract_address,
        claimed_token_id = record_nft_claim_to_chain.token_id,
        claimed_transaction_hash = record_nft_claim_to_chain.transaction_hash,
        claimed_at = NOW()
    WHERE cid = nft_cid;
    
    RETURN json_build_object(
        'success', true,
        'message', 'NFT claim recorded successfully',
        'cid', nft_cid,
        'claimed_chain', claimed_chain,
        'token_id', token_id,
        'transaction_hash', transaction_hash
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Step 8: Function to get chain distribution statistics
CREATE OR REPLACE FUNCTION get_chain_distribution_stats()
RETURNS JSON
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'chain', assigned_chain,
            'total_nfts', COUNT(*),
            'available', COUNT(*) FILTER (WHERE is_distributed = false),
            'distributed', COUNT(*) FILTER (WHERE is_distributed = true),
            'rarities', (
                SELECT json_object_agg(
                    rarity::TEXT,
                    json_build_object(
                        'total', COUNT(*),
                        'available', COUNT(*) FILTER (WHERE is_distributed = false)
                    )
                )
                FROM nft_cid_pools p2
                WHERE p2.assigned_chain = p1.assigned_chain
                GROUP BY p2.assigned_chain, p2.rarity
            )
        )
    ) INTO result
    FROM (
        SELECT DISTINCT assigned_chain 
        FROM nft_cid_pools 
        WHERE assigned_chain IS NOT NULL
    ) p1;
    
    RETURN COALESCE(result, '[]'::JSON);
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON nft_cid_pools TO authenticated;
GRANT SELECT, INSERT, UPDATE ON nft_cid_distribution_log TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_available_cid_by_chain TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_unique_nft_with_chain TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_cid_counts_by_chain TO authenticated;
GRANT EXECUTE ON FUNCTION can_claim_nft_to_chain TO authenticated;
GRANT EXECUTE ON FUNCTION record_nft_claim_to_chain TO authenticated;
GRANT EXECUTE ON FUNCTION get_chain_distribution_stats TO authenticated;

-- Create comment for documentation
COMMENT ON COLUMN nft_cid_pools.assigned_chain IS 'Blockchain network this NFT is assigned to (e.g., polygon-amoy, sepolia, bsc-testnet)';
COMMENT ON COLUMN nft_cid_pools.chain_id IS 'Chain ID of the assigned blockchain (e.g., 80002 for Polygon Amoy)';
COMMENT ON COLUMN nft_cid_pools.chain_contract_address IS 'NFT contract address on the assigned chain';
COMMENT ON COLUMN nft_cid_pools.can_claim_to_any_chain IS 'If true, NFT can be claimed to any supported chain; if false, only to assigned_chain';

COMMENT ON FUNCTION get_next_available_cid_by_chain IS 'Get next available NFT CID for specific chain and rarity';
COMMENT ON FUNCTION distribute_unique_nft_with_chain IS 'Distribute NFT to user with optional chain specification';
COMMENT ON FUNCTION can_claim_nft_to_chain IS 'Validate if NFT can be claimed to specific blockchain';
COMMENT ON FUNCTION record_nft_claim_to_chain IS 'Record NFT claim transaction to blockchain';
COMMENT ON FUNCTION get_chain_distribution_stats IS 'Get statistics of NFT distribution across chains';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Chain-specific NFT distribution system migration completed successfully!';
    RAISE NOTICE '📊 New features added:';
    RAISE NOTICE '   - Chain assignment fields in nft_cid_pools table';
    RAISE NOTICE '   - Chain tracking in distribution log';
    RAISE NOTICE '   - Chain-specific distribution functions';
    RAISE NOTICE '   - Chain validation and claiming functions';
    RAISE NOTICE '   - Chain distribution statistics';
END $$;
