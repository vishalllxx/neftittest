-- ============================================================================
-- FIX CHAIN-SPECIFIC NFT DISTRIBUTION FUNCTIONS
-- ============================================================================
-- This fixes the "record has no field can_claim_to_any_chain" error
-- by updating the get_next_available_cid function to include new fields
-- ============================================================================

-- Step 1: Update the original get_next_available_cid function to include chain fields
DROP FUNCTION IF EXISTS get_next_available_cid(VARCHAR);

CREATE OR REPLACE FUNCTION get_next_available_cid(
    target_rarity VARCHAR(20)
) RETURNS TABLE(
    cid VARCHAR(100),
    image_url TEXT,
    metadata_cid VARCHAR(100),
    pool_id INTEGER,
    assigned_chain VARCHAR(50),
    chain_id INTEGER,
    chain_contract_address VARCHAR(100),
    can_claim_to_any_chain BOOLEAN
) 
SECURITY DEFINER
AS $$
BEGIN
    -- Get the next available CID for the specified rarity (any chain)
    RETURN QUERY
    SELECT 
        p.cid,
        p.image_url,
        p.metadata_cid,
        p.id as pool_id,
        p.assigned_chain,
        p.chain_id,
        p.chain_contract_address,
        COALESCE(p.can_claim_to_any_chain, false) as can_claim_to_any_chain
    FROM nft_cid_pools p
    WHERE p.rarity = target_rarity::nft_rarity 
    AND p.is_distributed = FALSE
    ORDER BY p.created_at DESC, p.id DESC 
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Update get_next_available_cid_by_chain to use COALESCE for safety
DROP FUNCTION IF EXISTS get_next_available_cid_by_chain(VARCHAR, VARCHAR);

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
    chain_contract_address VARCHAR(100),
    can_claim_to_any_chain BOOLEAN
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
        p.chain_contract_address,
        COALESCE(p.can_claim_to_any_chain, false) as can_claim_to_any_chain
    FROM nft_cid_pools p
    WHERE p.rarity = target_rarity::nft_rarity 
    AND p.is_distributed = FALSE
    AND p.assigned_chain = target_chain
    ORDER BY p.created_at DESC, p.id DESC 
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Fix distribute_unique_nft_with_chain to handle both cases properly
DROP FUNCTION IF EXISTS distribute_unique_nft_with_chain(VARCHAR, VARCHAR, VARCHAR);

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
    selected_chain VARCHAR(50);
BEGIN
    -- Generate unique NFT ID
    nft_id := 'nft_' || target_rarity || '_' || EXTRACT(EPOCH FROM NOW())::BIGINT || '_' || (RANDOM() * 1000)::INTEGER;
    
    -- If no chain specified, get next available from any chain
    IF target_chain IS NULL OR target_chain = '' THEN
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
                     CASE WHEN target_chain IS NOT NULL AND target_chain != '' 
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
            'can_claim_to_any_chain', COALESCE(available_cid.can_claim_to_any_chain, false),
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_next_available_cid TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_available_cid TO anon;
GRANT EXECUTE ON FUNCTION get_next_available_cid_by_chain TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_available_cid_by_chain TO anon;
GRANT EXECUTE ON FUNCTION distribute_unique_nft_with_chain TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_unique_nft_with_chain TO anon;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Chain distribution functions fixed successfully!';
    RAISE NOTICE '📋 Updated functions:';
    RAISE NOTICE '   - get_next_available_cid (now includes chain fields)';
    RAISE NOTICE '   - get_next_available_cid_by_chain (improved)';
    RAISE NOTICE '   - distribute_unique_nft_with_chain (fixed field access)';
END $$;
