# AQUACAMPUS Firebase-connected Android APK build.
# The Firebase public Android configuration is embedded in
# lib/firebase_android_config.dart, sourced from aquacampus-ed284.
param([switch]$LiveFirebase)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Flutter-Run {
  param([string[]]$FlutterArgs)
  & flutter @FlutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter step failed ($($FlutterArgs -join ' ')), code $LASTEXITCODE"
  }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is not on PATH. Install Flutter and Android SDK first.'
}
$config = Join-Path $PSScriptRoot 'lib\firebase_android_config.dart'
if (-not (Test-Path $config)) {
  throw 'Registered Firebase Android client configuration missing.'
}
if (-not (Select-String -Path $config -Pattern "aquacampus-ed284" -SimpleMatch -Quiet)) {
  throw 'The Android app is not configured for Firebase project aquacampus-ed284.'
}
if (-not (Test-Path (Join-Path $PSScriptRoot 'android'))) {
  throw 'Android platform missing. Run flutter create --platforms android .'
}

Flutter-Run -FlutterArgs @('pub', 'get')
Flutter-Run -FlutterArgs @('analyze', '--no-fatal-infos', '--no-fatal-warnings')
Flutter-Run -FlutterArgs @('test')
Flutter-Run -FlutterArgs @('build', 'apk', '--release')

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
  throw "Android build completed but APK is missing: $apk"
}
$folder = Join-Path $PSScriptRoot 'release'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$target = Join-Path $folder 'AQUACAMPUS-FIREBASE-LIVE.apk'
Copy-Item -Path $apk -Destination $target -Force
Write-Host "Compiled Android APK: $target" -ForegroundColor Green
Write-Host 'Firebase client config is included. Auth, Firestore, deployed security rules and multi-phone workflow still need end-to-end verification.' -ForegroundColor Yellow
