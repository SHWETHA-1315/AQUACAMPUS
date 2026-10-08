@echo off
setlocal
title AQUACAMPUS Backend + Android
cd /d "%~dp0"
echo ============================================================
echo       AQUACAMPUS - REAL FIREBASE BACKEND DEPLOYMENT
echo ============================================================
echo Firebase project: aquacampus-ed284
echo Android package: com.example.aquacampus
echo Authentication: Email/Password
echo Firestore rules: Role-scoped, no demo accounts
echo.
echo A browser-based owner Google sign-in is required.
echo Review rules before accepting their deployment.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0START_AQUACAMPUS_FIREBASE.ps1"
if errorlevel 1 (
  echo Backend not deployed. Review the error before retrying.
  pause
  exit /b 1
)
echo.
echo Firebase backend deployment command finished.
echo Do not publish until role testing and a verified first Admin are complete.
echo.
echo Optional: build the Android APK now.
choice /C YN /M "Build Android APK"
if errorlevel 2 goto DONE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk.ps1" -LiveFirebase
if errorlevel 1 (
  echo Android build failed. Backend deployment was not undone.
  pause
  exit /b 1
)
echo Generated APK: release\AQUACAMPUS-FIREBASE-LIVE.apk
:DONE
echo.
echo First Admin steps:
echo 1. Register the intended account via installed AQUACAMPUS app.
echo 2. On your own PC, run PowerShell:
echo    .\BOOTSTRAP_ADMIN.ps1 -Email your-real-email@example.com
echo 3. Reopen app. Admin can assign real people, facilities and rooms.
echo 4. Verify two-phone realtime updates and Firestore security rules.
pause
endlocal
