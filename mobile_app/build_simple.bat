@echo off
echo SmartPulse APK Build Script
echo ============================
echo.

echo Step 1: Checking Flutter environment...
flutter doctor -v

echo.
echo Step 2: Enabling Developer Mode...
start ms-settings:developers
echo Please enable Developer Mode in Windows Settings, then press any key to continue...
pause

echo.
echo Step 3: Getting dependencies...
flutter pub get

echo.
echo Step 4: Building APK...
flutter build apk --debug --verbose

echo.
echo Build process completed!
echo.
echo APK location: build\app\outputs\flutter-apk\app-debug.apk
echo.
echo If build failed, please:
echo 1. Enable Developer Mode in Windows Settings
echo 2. Install Android Studio and required SDK components
echo 3. Run 'flutter doctor --android-licenses'
echo 4. Check Android SDK installation
echo.
pause
