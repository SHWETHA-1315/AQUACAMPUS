# Run AQUACAMPUS as a REAL Flutter app (Android phone/emulator).
# Use: .\RUN_LOCAL.ps1     or    .\RUN_LOCAL.ps1 -BuildApk
param([switch]$BuildApk)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK was not found in PATH. Install Flutter and Android SDK, then run flutter doctor.'
}
if (-not (Test-Path '.\android')) {
  & flutter create --platforms android --project-name aquacampus .
  if ($LASTEXITCODE -ne 0) { throw 'Flutter Android scaffold failed' }
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
if ($BuildApk) {
  & flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Flutter unit tests failed' }
  & flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'Release APK compilation failed' }
  Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
} else {
  & flutter devices
  & flutter run
  if ($LASTEXITCODE -ne 0) { throw 'flutter run failed. Check USB debugging/device and flutter doctor.' }
}
