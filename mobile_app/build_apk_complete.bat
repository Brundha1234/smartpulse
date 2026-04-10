@echo off
echo SmartPulse v2 - APK Build Script (Java 21 Compatible)
echo ==========================================================
echo.

echo Step 1: Checking Java version...
java -version

echo.
echo Step 2: Enabling Developer Mode...
echo Opening Windows Developer Settings...
start ms-settings:developers
echo.
echo IMPORTANT: Please enable "Developer Mode" in Windows Settings
echo Press any key when Developer Mode is enabled...
pause >nul

echo.
echo Step 3: Cleaning Flutter...
flutter clean

echo.
echo Step 4: Getting dependencies...
flutter pub get

echo.
echo Step 5: Building APK...
echo This may take 5-10 minutes...
echo.

flutter build apk --debug --verbose

echo.
echo Build completed!
echo.
echo APK Location: build\app\outputs\flutter-apk\app-debug.apk
echo.
echo To install APK:
echo 1. Transfer APK to Android device
echo 2. Enable "Install from unknown sources" in Android settings
echo 3. Tap APK file to install
echo.
pause
