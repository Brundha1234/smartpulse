@echo off
echo Building SmartPulse APK...
echo.

echo Step 1: Checking Flutter environment...
flutter doctor -v

echo.
echo Step 2: Cleaning previous builds...
flutter clean

echo.
echo Step 3: Getting dependencies...
flutter pub get

echo.
echo Step 4: Building debug APK...
flutter build apk --debug

echo.
echo Build completed!
echo APK location: build\outputs\flutter-apk\app-debug.apk
echo.
echo To install on device:
echo 1. Enable USB debugging on your Android device
echo 2. Connect device via USB
echo 3. Run: adb install build\outputs\flutter-apk\app-debug.apk
echo.
pause
