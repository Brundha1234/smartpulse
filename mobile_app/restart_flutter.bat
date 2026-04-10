@echo off
echo SmartPulse v2 - Clean Restart
echo ============================
echo.

echo Step 1: Stopping any running Flutter processes...
taskkill /F /IM flutter.exe 2>nul
taskkill /F /IM dart.exe 2>nul

echo Step 2: Cleaning Flutter cache...
flutter clean

echo Step 3: Getting dependencies...
flutter pub get

echo Step 4: Starting Flutter app...
echo.
echo IMPORTANT: Make sure Developer Mode is enabled in Windows Settings!
echo.

flutter run -d chrome --web-port=8081

echo.
echo If Provider error persists:
echo 1. Stop app completely (Ctrl+C)
echo 2. Run this script again
echo 3. Check that backend is running on http://127.0.0.1:5000
echo.
pause
