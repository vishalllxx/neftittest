-- ============================================================================
-- NONCE-BASED WALLET AUTHENTICATION SYSTEM
-- ============================================================================
-- This migration adds secure nonce-based authentication for wallet connections
-- Prevents wallet impersonation and replay attacks
-- ============================================================================

-- Drop existing auth_nonces table to ensure clean schema
DROP TABLE IF EXISTS auth_nonces CASCADE;

-- Create auth_nonces table to store nonces for signature verification
CREATE TABLE auth_nonces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_address TEXT NOT NULL,
  nonce TEXT NOT NULL UNIQUE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '5 minutes',
  used BOOLEAN DEFAULT FALSE,
  used_at TIMESTAMPTZ DEFAULT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_auth_nonces_wallet ON auth_nonces(wallet_address);
CREATE INDEX IF NOT EXISTS idx_auth_nonces_nonce ON auth_nonces(nonce);
CREATE INDEX IF NOT EXISTS idx_auth_nonces_expires ON auth_nonces(expires_at);
CREATE INDEX IF NOT EXISTS idx_auth_nonces_used ON auth_nonces(used);

-- Enable RLS on auth_nonces table
ALTER TABLE auth_nonces ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for auth_nonces (drop if exists first)
DROP POLICY IF EXISTS "Anyone can generate nonces" ON auth_nonces;
DROP POLICY IF EXISTS "Anyone can read their own nonces" ON auth_nonces;

CREATE POLICY "Anyone can generate nonces" 
  ON auth_nonces FOR INSERT 
  WITH CHECK (true);

CREATE POLICY "Anyone can read their own nonces" 
  ON auth_nonces FOR SELECT 
  USING (wallet_address = current_setting('request.headers', true)::json->>'x-wallet-address');

-- ============================================================================
-- Drop existing functions to avoid type conflicts
-- ============================================================================
DROP FUNCTION IF EXISTS generate_auth_nonce(TEXT);
DROP FUNCTION IF EXISTS verify_and_consume_nonce(TEXT, TEXT);
DROP FUNCTION IF EXISTS cleanup_expired_nonces();
DROP FUNCTION IF EXISTS get_nonce_stats();

-- ============================================================================
-- Function: generate_auth_nonce
-- Generates a unique nonce for wallet authentication
-- ============================================================================
CREATE OR REPLACE FUNCTION generate_auth_nonce(
  p_wallet_address TEXT
)
RETURNS TABLE(
  nonce TEXT,
  message TEXT,
  expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_nonce TEXT;
  v_message TEXT;
  v_expiry TIMESTAMPTZ;
BEGIN
  -- Clean up expired nonces for this wallet (housekeeping)
  DELETE FROM auth_nonces 
  WHERE auth_nonces.wallet_address = p_wallet_address 
    AND auth_nonces.expires_at < NOW();
  
  -- Clean up old used nonces (older than 1 hour)
  DELETE FROM auth_nonces 
  WHERE auth_nonces.wallet_address = p_wallet_address 
    AND auth_nonces.used = TRUE 
    AND auth_nonces.used_at < NOW() - INTERVAL '1 hour';
  
  -- Generate cryptographically secure random nonce
  v_nonce := encode(gen_random_bytes(32), 'hex');
  
  -- Create authentication message
  v_message := format(
    E'Sign this message to authenticate with NEFTIT\n\n' ||
    'Wallet: %s\n' ||
    'Nonce: %s\n' ||
    'Timestamp: %s\n\n' ||
    'This signature will not trigger any blockchain transaction or cost gas fees.',
    p_wallet_address,
    v_nonce,
    extract(epoch from NOW())::bigint
  );
  
  -- Set expiry time (5 minutes from now)
  v_expiry := NOW() + INTERVAL '5 minutes';
  
  -- Insert nonce into table
  INSERT INTO auth_nonces (wallet_address, nonce, message, expires_at)
  VALUES (p_wallet_address, v_nonce, v_message, v_expiry);
  
  -- Return values using completely different variable names to avoid ANY ambiguity
  nonce := v_nonce;
  message := v_message;
  expires_at := v_expiry;
  RETURN NEXT;
END;
$$;

-- ============================================================================
-- Function: verify_and_consume_nonce
-- Verifies nonce validity and marks it as used
-- Note: Actual signature verification happens in application layer
-- ============================================================================
CREATE OR REPLACE FUNCTION verify_and_consume_nonce(
  p_wallet_address TEXT,
  p_nonce TEXT
)
RETURNS TABLE(
  valid BOOLEAN,
  message TEXT,
  error_reason TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  nonce_record RECORD;
BEGIN
  -- Normalize wallet address to lowercase
  p_wallet_address := lower(p_wallet_address);
  
  -- Find the nonce
  SELECT * INTO nonce_record 
  FROM auth_nonces 
  WHERE nonce = p_nonce 
    AND lower(wallet_address) = p_wallet_address
  FOR UPDATE;
  
  -- Check if nonce exists
  IF NOT FOUND THEN
    RETURN QUERY SELECT 
      FALSE, 
      NULL::TEXT,
      'Nonce not found or does not match wallet address'::TEXT;
    RETURN;
  END IF;
  
  -- Check if nonce has already been used
  IF nonce_record.used = TRUE THEN
    RETURN QUERY SELECT 
      FALSE, 
      NULL::TEXT,
      'Nonce has already been used'::TEXT;
    RETURN;
  END IF;
  
  -- Check if nonce has expired
  IF nonce_record.expires_at < NOW() THEN
    -- Clean up expired nonce
    DELETE FROM auth_nonces WHERE nonce = p_nonce;
    
    RETURN QUERY SELECT 
      FALSE, 
      NULL::TEXT,
      'Nonce has expired'::TEXT;
    RETURN;
  END IF;
  
  -- Mark nonce as used
  UPDATE auth_nonces 
  SET 
    used = TRUE,
    used_at = NOW()
  WHERE nonce = p_nonce;
  
  -- Return success
  RETURN QUERY SELECT 
    TRUE,
    nonce_record.message,
    NULL::TEXT;
END;
$$;

-- ============================================================================
-- Function: cleanup_expired_nonces
-- Maintenance function to clean up expired and used nonces
-- Should be run periodically (e.g., via cron job)
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_expired_nonces()
RETURNS TABLE(
  deleted_expired INTEGER,
  deleted_old_used INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_count INTEGER;
  used_count INTEGER;
BEGIN
  -- Delete expired nonces
  DELETE FROM auth_nonces 
  WHERE expires_at < NOW();
  
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  
  -- Delete old used nonces (older than 24 hours)
  DELETE FROM auth_nonces 
  WHERE used = TRUE 
    AND used_at < NOW() - INTERVAL '24 hours';
  
  GET DIAGNOSTICS used_count = ROW_COUNT;
  
  RETURN QUERY SELECT expired_count, used_count;
END;
$$;

-- ============================================================================
-- Function: get_nonce_stats
-- Get statistics about nonces for monitoring
-- ============================================================================
CREATE OR REPLACE FUNCTION get_nonce_stats()
RETURNS TABLE(
  total_nonces BIGINT,
  active_nonces BIGINT,
  used_nonces BIGINT,
  expired_nonces BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::BIGINT as total,
    COUNT(*) FILTER (WHERE used = FALSE AND expires_at > NOW())::BIGINT as active,
    COUNT(*) FILTER (WHERE used = TRUE)::BIGINT as used,
    COUNT(*) FILTER (WHERE expires_at < NOW())::BIGINT as expired
  FROM auth_nonces;
END;
$$;

-- ============================================================================
-- Grant necessary permissions
-- ============================================================================
GRANT EXECUTE ON FUNCTION generate_auth_nonce(TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION verify_and_consume_nonce(TEXT, TEXT) TO authenticated, anon, public;
GRANT EXECUTE ON FUNCTION cleanup_expired_nonces() TO authenticated;
GRANT EXECUTE ON FUNCTION get_nonce_stats() TO authenticated;

-- ============================================================================
-- Create comments for documentation
-- ============================================================================
COMMENT ON TABLE auth_nonces IS 'Stores nonces for secure wallet authentication';
COMMENT ON FUNCTION generate_auth_nonce(TEXT) IS 'Generates a unique nonce for wallet signature verification';
COMMENT ON FUNCTION verify_and_consume_nonce(TEXT, TEXT) IS 'Verifies and consumes a nonce, marking it as used';
COMMENT ON FUNCTION cleanup_expired_nonces() IS 'Maintenance function to clean up expired and old used nonces';
COMMENT ON FUNCTION get_nonce_stats() IS 'Returns statistics about nonces for monitoring';

-- ============================================================================
-- Success message
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE 'Nonce-based authentication system installed successfully!';
  RAISE NOTICE 'Tables created: auth_nonces';
  RAISE NOTICE 'Functions created: generate_auth_nonce, verify_and_consume_nonce, cleanup_expired_nonces, get_nonce_stats';
END $$;
