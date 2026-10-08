# AQUACAMPUS — run as a native Flutter Android application on Windows.
# Prerequisites: Flutter SDK and Android SDK available on PATH.
$ErrorActionPreference = "Stop"
flutter doctor
if ($LASTEXITCODE -ne 0) { Write-Host "Resolve Flutter Doctor issues first."; exit 1 }
if (!(Test-Path "./android")) { flutter create --platforms=android --project-name aquacampus . }
if ($LASTEXITCODE -ne 0) { exit 1 }
flutter pub get
if ($LASTEXITCODE -ne 0) { exit 1 }
flutter devices
flutter run
