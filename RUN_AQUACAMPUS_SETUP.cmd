@echo off
setlocal
title AQUACAMPUS Firebase Setup + Android APK
cd /d "%~dp0"
echo ================================================================
echo        AQUACAMPUS - REAL FIREBASE ANDROID SETUP
echo ================================================================
echo Firebase project: aquacampus-ed284
echo Android package: com.example.aquacampus
echo.
echo This setup requires the Firebase project owner's Google sign-in.
echo No demo users or fabricated campus measurements will be created.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0START_AQUACAMPUS_FIREBASE.ps1"
if errorlevel 1 (
  echo.
  echo Backend setup stopped. Please review the error above.
  pause
  exit /b 1
)
echo.
echo Firebase Auth Email/Password must be enabled in the Firebase Console.
echo Open: https://console.firebase.google.com/project/aquacampus-ed284/authentication/providers
echo.
choice /C YN /M "Did you enable Email/Password Authentication in Firebase?"
if errorlevel 2 (
  echo Enable the provider before trying the Android app.
  pause
  exit /b 1
)
echo.
echo Building the real Android APK for Firebase project aquacampus-ed284...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk.ps1" -LiveFirebase
if errorlevel 1 (
  echo.
  echo APK build failed. Check Flutter and Android SDK installation.
  pause
  exit /b 1
)
echo.
echo ================================================================
echo SUCCESS: release\AQUACAMPUS-FIREBASE-LIVE.apk
echo ================================================================
echo IMPORTANT: The first admin must still be approved using Firebase Console.
echo Other users need admin assignment before accessing real campus data.
pause
endlocal
