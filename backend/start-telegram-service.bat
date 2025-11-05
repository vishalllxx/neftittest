@echo off
echo Starting Telegram Verification Service...
echo.

REM Check if node_modules exists, if not install dependencies
if not exist "node_modules" (
    echo Installing dependencies...
    npm install --prefix . --package-lock=false
    echo.
)

REM Set environment variables
set TELEGRAM_VERIFICATION_PORT=3004
set TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here

echo Configuration:
echo - Port: %TELEGRAM_VERIFICATION_PORT%
echo - Bot Token: %TELEGRAM_BOT_TOKEN%
echo.

echo Starting service...
node telegram-verification-service.js

pause
