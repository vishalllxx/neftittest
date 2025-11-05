import { supabase } from '@/lib/supabase';

export interface DiscordVerificationResult {
  success: boolean;
  message: string;
  isMember?: boolean;
  hasRole?: boolean;
  error?: string;
}

export class DiscordVerificationService {
  // No hardcoded values - all Discord IDs must come from task configuration

  /**
   * Verify if a user has joined the Discord server
   * @param userId Discord user ID
   * @param guildId Discord server/guild ID (required - no fallback)
   */
  static async verifyDiscordMembership(userId: string, guildId: string): Promise<DiscordVerificationResult> {
    try {
      // Guild ID is required - no fallback to hardcoded values
      if (!guildId) {
        return {
          success: false,
          message: 'Discord Guild ID is required for verification',
          error: 'MISSING_GUILD_ID'
        };
      }
      
      const targetGuildId = guildId;
      
      console.log('=== DISCORD MEMBERSHIP VERIFICATION START ===');
      console.log('User ID to verify:', userId);
      console.log('User ID type:', typeof userId);
      console.log('User ID length:', userId?.length);
      console.log('Guild ID to check:', targetGuildId);
      console.log('Guild ID source:', 'task-specific');
      
      const requestBody = {
        discordUserId: userId,
        guildId: targetGuildId
      };
      console.log('Request body being sent:', requestBody);
      console.log('Request body JSON:', JSON.stringify(requestBody));
      
      // Use backend service instead of Supabase Edge Function
      const response = await fetch('http://localhost:3001/verify-discord-join', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();
      console.log('Discord membership verification response:', data);
      console.log('Response status:', response.status);
      console.log('Response ok:', response.ok);
      console.log('Response headers:', Object.fromEntries(response.headers.entries()));
      console.log('=== DISCORD MEMBERSHIP VERIFICATION END ===');

      if (!response.ok) {
        console.error('Discord membership verification error:', data);
        return {
          success: false,
          message: data.message || 'Failed to verify Discord membership',
          error: data.error || 'HTTP error'
        };
      }

      if (data.isMember) {
        return {
          success: true,
          message: data.message || 'Discord membership verified successfully!',
          isMember: true
        };
      } else {
        return {
          success: false,
          message: data.message || 'User not found in Discord server',
          isMember: false
        };
      }
    } catch (error) {
      console.error('Discord membership verification service error:', error);
      return {
        success: false,
        message: 'Internal error during Discord membership verification',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Verify if a user has the required role in the Discord server
   * @param userId Discord user ID
   * @param guildId Discord server/guild ID (required - no fallback)
   * @param roleId Discord role ID (required - no fallback)
   */
  static async verifyDiscordRole(userId: string, guildId: string, roleId: string): Promise<DiscordVerificationResult> {
    try {
      // Both Guild ID and Role ID are required - no fallback to hardcoded values
      if (!guildId) {
        return {
          success: false,
          message: 'Discord Guild ID is required for verification',
          error: 'MISSING_GUILD_ID'
        };
      }
      
      if (!roleId) {
        return {
          success: false,
          message: 'Discord Role ID is required for verification',
          error: 'MISSING_ROLE_ID'
        };
      }
      
      const targetGuildId = guildId;
      const targetRoleId = roleId;
      
      console.log('=== DISCORD ROLE VERIFICATION START ===');
      console.log('User ID to verify:', userId);
      console.log('Guild ID to check:', targetGuildId);
      console.log('Role ID to check:', targetRoleId);
      console.log('Guild ID source:', 'task-specific');
      console.log('Role ID source:', 'task-specific');
      
      const requestBody = {
        discordUserId: userId,
        guildId: targetGuildId,
        roleId: targetRoleId
      };
      console.log('Request body being sent:', requestBody);
      
      // Use backend service instead of Supabase Edge Function
      const response = await fetch('http://localhost:3001/verify-discord-role', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();
      console.log('Discord role verification response:', data);
      console.log('=== DISCORD ROLE VERIFICATION END ===');

      if (!response.ok) {
        console.error('Discord role verification error:', data);
        return {
          success: false,
          message: data.message || 'Failed to verify Discord role',
          error: data.error || 'HTTP error'
        };
      }

      if (data.hasRole) {
        return {
          success: true,
          message: data.message || 'Discord role verified successfully!',
          hasRole: true
        };
      } else {
        return {
          success: false,
          message: data.message || 'Required role not found',
          hasRole: false
        };
      }
    } catch (error) {
      console.error('Discord role verification service error:', error);
      return {
        success: false,
        message: 'Internal error during Discord role verification',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Verify both Discord membership and role in a single call
   * @param userId Discord user ID
   * @param guildId Discord server/guild ID (required)
   * @param roleId Discord role ID (required)
   */
  static async verifyDiscordComplete(userId: string, guildId: string, roleId: string): Promise<DiscordVerificationResult> {
    try {
      // First verify membership
      const membershipResult = await this.verifyDiscordMembership(userId, guildId);
      if (!membershipResult.success || !membershipResult.isMember) {
        return {
          success: false,
          message: 'Please join the Discord server first before verifying role',
          isMember: false,
          hasRole: false
        };
      }

      // Then verify role
      const roleResult = await this.verifyDiscordRole(userId, guildId, roleId);
      return {
        success: roleResult.success,
        message: roleResult.message,
        isMember: true,
        hasRole: roleResult.hasRole
      };
    } catch (error) {
      console.error('Discord complete verification error:', error);
      return {
        success: false,
        message: 'Internal error during Discord verification',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Get the Discord invite link for the server
   * Note: This should be configured per project/task, not hardcoded
   */
  static getDiscordInviteLink(): string {
    return `https://t.co/4EeqEtQqw3`; // This should be made dynamic per project
  }

  /**
   * Test Discord API connectivity and bot permissions
   * @param guildId Discord server/guild ID to test
   * @param roleId Discord role ID to test
   */
  static async testDiscordAPI(guildId: string, roleId: string): Promise<{ success: boolean; message: string; error?: string; config?: any }> {
    try {
      console.log('=== TESTING DISCORD API CONNECTIVITY ===');
      console.log('Guild ID:', guildId);
      console.log('Role ID:', roleId);
      
      // Test backend health endpoint
      const response = await fetch('http://localhost:3001/health');
      const data = await response.json();
      
      console.log('Backend health response:', data);
      
      if (!response.ok) {
        return {
          success: false,
          message: 'Failed to connect to backend service',
          error: data.message || 'HTTP error'
        };
      }
      
      return {
        success: true,
        message: 'Backend service connectivity test successful',
        config: data.config
      };
    } catch (error) {
      console.error('Discord API test error:', error);
      return {
        success: false,
        message: 'Backend service test failed',
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }
}

export default DiscordVerificationService;
