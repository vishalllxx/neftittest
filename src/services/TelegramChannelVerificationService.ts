export interface TelegramVerificationResult {
  success: boolean;
  message: string;
  isMember: boolean;
  userStatus?: string;
  error?: string;
}

export class TelegramChannelVerificationService {
  /**
   * Check if a user is a member of a Telegram channel/group
   * For now, we'll use a simple verification approach without requiring bot tokens
   * @param telegramUserId - The user's Telegram user ID
   * @param channelId - The channel/group ID (can be @username or numeric ID)
   * @returns Promise<TelegramVerificationResult>
   */
  static async verifyChannelMembership(
    telegramUserId: string,
    channelId: string
  ): Promise<TelegramVerificationResult> {
    try {
      console.log('🔍 [Telegram] Verifying channel membership:', {
        telegramUserId,
        channelId: channelId.replace(/@/g, '')
      });

      if (!telegramUserId) {
        return {
          success: false,
          message: 'Telegram User ID is required',
          isMember: false,
          error: 'MISSING_USER_ID'
        };
      }

      if (!channelId) {
        return {
          success: false,
          message: 'Channel ID is required',
          isMember: false,
          error: 'MISSING_CHANNEL_ID'
        };
      }

      // For now, we'll use a simple approach: ask user to confirm they joined
      // This avoids the need for bot tokens and backend services
      const userConfirmed = await this.showConfirmationDialog(channelId);
      
      if (userConfirmed) {
        return {
          success: true,
          message: 'Channel membership confirmed by user',
          isMember: true,
          userStatus: 'member'
        };
      } else {
        return {
          success: false,
          message: 'Please join the Telegram channel first',
          isMember: false,
          error: 'USER_NOT_CONFIRMED'
        };
      }
    } catch (error: any) {
      console.error('❌ [Telegram] Channel verification error:', error);

      return {
        success: false,
        message: 'Failed to verify channel membership',
        isMember: false,
        error: error.message || 'UNKNOWN_ERROR'
      };
    }
  }

  /**
   * Show a confirmation dialog asking user to confirm they joined the channel
   * @param channelId - The channel ID to display
   * @returns Promise<boolean>
   */
  private static async showConfirmationDialog(channelId: string): Promise<boolean> {
    return new Promise((resolve) => {
      // Extract channel name from URL for display
      const channelName = this.extractChannelNameFromLink(channelId);
      
      const message = `Have you joined the Telegram channel ${channelName || channelId}?\n\nPlease confirm that you have joined the channel.`;
      
      const confirmed = window.confirm(message);
      resolve(confirmed);
    });
  }

  /**
   * Extract channel name from Telegram link for display
   * @param telegramLink - The Telegram link
   * @returns string | null
   */
  private static extractChannelNameFromLink(telegramLink: string): string | null {
    try {
      // Handle various Telegram link formats
      const patterns = [
        /https?:\/\/t\.me\/([a-zA-Z0-9_+]+)/,  // https://t.me/channelname
        /t\.me\/([a-zA-Z0-9_+]+)/,             // t.me/channelname
        /@([a-zA-Z0-9_+]+)/,                   // @channelname
        /^([a-zA-Z0-9_+]+)$/                   // channelname
      ];

      for (const pattern of patterns) {
        const match = telegramLink.match(pattern);
        if (match) {
          return `@${match[1]}`;
        }
      }

      return null;
    } catch (error) {
      console.error('❌ [Telegram] Error extracting channel name:', error);
      return null;
    }
  }

  /**
   * Extract channel ID from Telegram link
   * @param telegramLink - The Telegram link (e.g., https://t.me/channelname)
   * @returns string | null
   */
  static extractChannelIdFromLink(telegramLink: string): string | null {
    try {
      // Handle various Telegram link formats
      const patterns = [
        /https?:\/\/t\.me\/([a-zA-Z0-9_+]+)/,  // https://t.me/channelname
        /t\.me\/([a-zA-Z0-9_+]+)/,             // t.me/channelname
        /@([a-zA-Z0-9_+]+)/,                   // @channelname
        /^([a-zA-Z0-9_+]+)$/                   // channelname
      ];

      for (const pattern of patterns) {
        const match = telegramLink.match(pattern);
        if (match) {
          return `@${match[1]}`;
        }
      }

      return null;
    } catch (error) {
      console.error('❌ [Telegram] Error extracting channel ID:', error);
      return null;
    }
  }
}
