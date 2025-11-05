-- ============================================================================
-- Fix get_available_cid_counts_by_chain Function
-- ============================================================================
-- This function returns NFT availability statistics by chain and rarity
-- Run this if you get "structure of query does not match function result type" error

-- Drop existing function
DROP FUNCTION IF EXISTS get_available_cid_counts_by_chain() CASCADE;

-- Recreate function with correct return type
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
    COALESCE(ncp.assigned_chain, 'unassigned')::TEXT as assigned_chain,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE ncp.is_distributed = false) as available_count,
    COUNT(*) FILTER (WHERE ncp.is_distributed = true) as distributed_count
  FROM nft_cid_pools ncp
  GROUP BY ncp.rarity::TEXT, COALESCE(ncp.assigned_chain, 'unassigned')::TEXT
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_available_cid_counts_by_chain TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_cid_counts_by_chain TO anon;

-- Test the function
SELECT * FROM get_available_cid_counts_by_chain();

-- Expected output columns:
-- rarity | assigned_chain | total_count | available_count | distributed_count
