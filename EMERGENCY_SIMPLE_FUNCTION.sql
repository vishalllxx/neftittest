-- ============================================================================
-- EMERGENCY SIMPLE FUNCTION - Guaranteed to work
-- ============================================================================
-- This creates a basic function that will show achievements without complex logic
-- ============================================================================

-- Create a simple function that just returns achievements with basic status
CREATE OR REPLACE FUNCTION get_user_achievement_status(user_wallet TEXT)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  -- Simple query that just returns all achievements
  SELECT json_agg(
    json_build_object(
      'achievement_key', am.achievement_key,
      'title', am.title,
      'description', am.description,
      'category', am.category::text,
      'icon', am.icon,
      'neft_reward', am.neft_reward,
      'xp_reward', am.xp_reward,
      'required_count', am.required_count,
      'current_progress', 0,
      'status', CASE 
        WHEN uap.claimed_at IS NOT NULL THEN 'claimed'
        ELSE 'locked' 
      END,
      'claimed_at', uap.claimed_at,
      'progress_percentage', 0,
      'sort_order', am.sort_order
    ) ORDER BY am.sort_order
  ) INTO result
  FROM achievements_master am
  LEFT JOIN user_achievement_progress uap ON am.achievement_key = uap.achievement_key 
    AND uap.wallet_address = user_wallet
  WHERE am.is_active = TRUE;
  
  RETURN COALESCE(result, '[]'::json);
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'error', true,
      'message', 'Error getting achievements: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_achievement_status(TEXT) TO authenticated, anon, public;

-- Test the function
SELECT 'EMERGENCY SIMPLE FUNCTION CREATED!' as status;
SELECT get_user_achievement_status('test_wallet');

-- Show achievements count
SELECT COUNT(*) as achievements_count FROM achievements_master WHERE is_active = TRUE;
