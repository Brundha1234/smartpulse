@echo off
echo Building SmartPulse APK...
flutter build apk --release
if %ERRORLEVEL% EQU 0 (
    echo.
    echo APK built successfully!
    echo Installing APK...
    C:\Users\sai\AppData\Local\Android\sdk\platform-tools\adb.exe install build\app\outputs\flutter-apk\app-release.apk
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo APK installed successfully!
        echo Launching app...
        C:\Users\sai\AppData\Local\Android\sdk\platform-tools\adb.exe shell am start -n com.example.smartpulse
    ) else (
        echo.
        echo APK installation failed!
    )
) else (
    echo.
    echo APK build failed!
)
pause
