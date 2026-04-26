@echo off
echo =======================================================
echo Building SecretRoy Release Packages (Minimal Size)
echo =======================================================

echo.
echo Cleaning previous builds...
call flutter clean
call flutter pub get

echo.
echo [1/2] Building Windows App...
echo Flags: --obfuscate --split-debug-info
call flutter build windows --obfuscate --split-debug-info=build\windows\symbols

echo.
echo [2/2] Building Android APKs (Split per Architecture for minimal size)...
echo Flags: --split-per-abi --obfuscate --split-debug-info
call flutter build apk --split-per-abi --obfuscate --split-debug-info=build\app\symbols

echo.
echo =======================================================
echo Build Finished!
echo =======================================================
echo Windows EXE location: build\windows\x64\runner\Release\
echo Android APKs location: build\app\outputs\flutter-apk\
echo   - Install the specific APK for your device architecture (e.g., arm64-v8a)
echo     instead of the fat apk to save space.
echo =======================================================
pause
