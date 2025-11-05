const express = require('express');
const axios = require('axios');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.TELEGRAM_VERIFICATION_PORT || 3004;

// Middleware
app.use(cors());
app.use(express.json());

// Configuration
const CONFIG = {
  TELEGRAM_BOT_TOKEN: process.env.TELEGRAM_BOT_TOKEN,
  API_BASE_URL: 'https://api.telegram.org/bot'
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'telegram-verification-service',
    timestamp: new Date().toISOString(),
    config: {
      hasBotToken: !!CONFIG.TELEGRAM_BOT_TOKEN,
      port: PORT
    }
  });
});

// Verify Telegram channel membership
app.post('/verify-telegram-channel', async (req, res) => {
  try {
    const { telegramUserId, channelId } = req.body;

    console.log('🔍 [Telegram] Verifying channel membership:', {
      telegramUserId,
      channelId,
      hasBotToken: !!CONFIG.TELEGRAM_BOT_TOKEN
    });

    // Validation
    if (!CONFIG.TELEGRAM_BOT_TOKEN) {
      return res.status(500).json({
        success: false,
        message: 'Telegram Bot Token not configured',
        error: 'MISSING_BOT_TOKEN'
      });
    }

    if (!telegramUserId) {
      return res.status(400).json({
        success: false,
        message: 'Telegram User ID is required',
        error: 'MISSING_USER_ID'
      });
    }

    if (!channelId) {
      return res.status(400).json({
        success: false,
        message: 'Channel ID is required',
        error: 'MISSING_CHANNEL_ID'
      });
    }

    // Clean channel ID (remove @ if present)
    const cleanChannelId = channelId.replace(/^@/, '');

    // Call Telegram Bot API
    const response = await axios.get(
      `${CONFIG.API_BASE_URL}${CONFIG.TELEGRAM_BOT_TOKEN}/getChatMember`,
      {
        params: {
          chat_id: cleanChannelId,
          user_id: telegramUserId
        },
        timeout: 10000 // 10 second timeout
      }
    );

    console.log('📡 [Telegram] API Response:', response.data);

    if (response.data.ok) {
      const status = response.data.result?.status;
      const isMember = ['member', 'administrator', 'creator'].includes(status);

      res.json({
        success: true,
        message: isMember ? 'User is a member of the channel' : 'User is not a member of the channel',
        isMember,
        userStatus: status,
        channelId: cleanChannelId
      });
    } else {
      res.status(400).json({
        success: false,
        message: 'Failed to check channel membership',
        error: 'API_ERROR'
      });
    }
  } catch (error) {
    console.error('❌ [Telegram] Channel verification error:', error);

    // Handle specific Telegram API errors
    if (error.response?.data) {
      const errorData = error.response.data;
      
      if (errorData.error_code === 400) {
        if (errorData.description?.includes('user not found')) {
          return res.status(400).json({
            success: false,
            message: 'User not found in Telegram',
            error: 'USER_NOT_FOUND'
          });
        }
        if (errorData.description?.includes('chat not found')) {
          return res.status(400).json({
            success: false,
            message: 'Channel not found. Please check the channel ID.',
            error: 'CHANNEL_NOT_FOUND'
          });
        }
        if (errorData.description?.includes('bot is not a member')) {
          return res.status(400).json({
            success: false,
            message: 'Bot is not a member of the channel. Please add the bot to the channel first.',
            error: 'BOT_NOT_MEMBER'
          });
        }
      }
      
      if (errorData.error_code === 403) {
        return res.status(403).json({
          success: false,
          message: 'Bot does not have permission to check members. Please make the bot an admin.',
          error: 'BOT_NO_PERMISSION'
        });
      }
    }

    res.status(500).json({
      success: false,
      message: 'Failed to verify channel membership',
      error: error.message || 'UNKNOWN_ERROR'
    });
  }
});

// Test bot configuration
app.get('/test-bot', async (req, res) => {
  try {
    if (!CONFIG.TELEGRAM_BOT_TOKEN) {
      return res.status(500).json({
        success: false,
        message: 'Telegram Bot Token not configured'
      });
    }

    const response = await axios.get(
      `${CONFIG.API_BASE_URL}${CONFIG.TELEGRAM_BOT_TOKEN}/getMe`,
      { timeout: 5000 }
    );
    
    res.json({
      success: response.data.ok,
      botInfo: response.data.result,
      message: response.data.ok ? 'Bot configuration is valid' : 'Bot configuration is invalid'
    });
  } catch (error) {
    console.error('❌ [Telegram] Bot test error:', error);
    res.status(500).json({
      success: false,
      message: 'Bot test failed',
      error: error.message
    });
  }
});

// Extract channel ID from Telegram link
app.post('/extract-channel-id', (req, res) => {
  try {
    const { telegramLink } = req.body;

    if (!telegramLink) {
      return res.status(400).json({
        success: false,
        message: 'Telegram link is required',
        error: 'MISSING_LINK'
      });
    }

    // Handle various Telegram link formats
    const patterns = [
      /https?:\/\/t\.me\/([a-zA-Z0-9_]+)/,  // https://t.me/channelname
      /t\.me\/([a-zA-Z0-9_]+)/,             // t.me/channelname
      /@([a-zA-Z0-9_]+)/,                   // @channelname
      /^([a-zA-Z0-9_]+)$/                   // channelname
    ];

    let extractedChannelId = null;
    for (const pattern of patterns) {
      const match = telegramLink.match(pattern);
      if (match) {
        extractedChannelId = `@${match[1]}`;
        break;
      }
    }

    res.json({
      success: true,
      channelId: extractedChannelId,
      originalLink: telegramLink
    });
  } catch (error) {
    console.error('❌ [Telegram] Channel ID extraction error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to extract channel ID',
      error: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Telegram Verification Service running on port ${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
  console.log(`🤖 Bot test: http://localhost:${PORT}/test-bot`);
  console.log(`🔧 Config:`, {
    hasBotToken: !!CONFIG.TELEGRAM_BOT_TOKEN,
    port: PORT
  });
});

module.exports = app;
