@echo off
echo SmartPulse v2 - App Launcher
echo ============================
echo.

echo Checking if backend is running...
curl -s http://127.0.0.1:5000/health >nul 2>&1
if %errorlevel% neq 0 (
    echo Backend is not running. Starting backend...
    start "Backend" cmd /k "cd ..\backend && python app.py"
    timeout /t 3 >nul
)

echo.
echo Starting Flutter app...
echo Make sure Developer Mode is enabled in Windows Settings!
echo.

flutter run -d chrome --web-port=8081

echo.
echo If app fails to start:
echo 1. Enable Developer Mode in Windows Settings
echo 2. Run 'flutter doctor' to check setup
echo 3. Check if backend is running on http://127.0.0.1:5000
echo.
pause
