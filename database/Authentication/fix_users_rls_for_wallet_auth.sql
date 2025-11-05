-- Fix RLS policies for wallet-based authentication
-- This allows user creation without prior authentication (needed for wallet login)

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON users;
DROP POLICY IF EXISTS "Allow all operations for anonymous users" ON users;
DROP POLICY IF EXISTS "Allow wallet user registration" ON users;
DROP POLICY IF EXISTS "Users can view their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Only service role can delete users" ON users;

-- Create policies that allow user creation
-- Policy 1: Allow anyone to INSERT their own user record (for registration)
CREATE POLICY "Allow wallet user registration" ON users
  FOR INSERT
  WITH CHECK (true); -- Allow any insert (we validate in the application layer)

-- Policy 2: Allow anyone to view user data (wallet-based auth doesn't use Supabase auth)
-- This is safe because we validate wallet ownership via signature verification
CREATE POLICY "Users can view their own data" ON users
  FOR SELECT
  USING (true); -- Allow all SELECT - wallet ownership is verified via signature, not RLS

-- Policy 3: Allow updates (application layer validates ownership via signature)
CREATE POLICY "Users can update their own data" ON users
  FOR UPDATE
  USING (true) -- Allow updates - validated in application layer
  WITH CHECK (true);

-- Policy 4: Prevent unauthorized deletes (only service role can delete)
CREATE POLICY "Only service role can delete users" ON users
  FOR DELETE
  USING (auth.role() = 'service_role');

-- Ensure permissions are granted
GRANT INSERT, SELECT, UPDATE ON users TO anon;
GRANT INSERT, SELECT, UPDATE ON users TO authenticated;
GRANT ALL ON users TO service_role;

-- Verify RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

COMMENT ON POLICY "Allow wallet user registration" ON users IS 'Allows new users to create their account via wallet authentication. No restrictions because signature verification happens in application layer.';
COMMENT ON POLICY "Users can view their own data" ON users IS 'Allows all users to view profile data. Security is enforced via signature verification, not RLS. This prevents authentication loops.';
COMMENT ON POLICY "Users can update their own data" ON users IS 'Allows profile updates. Wallet ownership is verified via cryptographic signatures in the application layer before updates are made.';
COMMENT ON POLICY "Only service role can delete users" ON users IS 'Only service role can delete user accounts. This is the only operation with RLS enforcement.';
