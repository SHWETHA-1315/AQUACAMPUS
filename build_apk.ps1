# AQUACAMPUS · Build the actual Firebase-connected Android APK.
# Setup: put the existing aquacampus-ed284 Android app's google-services.json
# in C:\AQUACAMPUS\android\app\. No example data or demo login is used.
param([switch]$LiveFirebase)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$ProjectId = 'aquacampus-ed284'
$AndroidPackage = 'com.example.aquacampus'
$ConfigFile = Join-Path $PSScriptRoot 'android\app\google-services.json'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK not found. Install Flutter and Android SDK on this PC.'
}
if (-not (Test-Path $ConfigFile)) {
  throw "Firebase Android configuration missing at $ConfigFile. Open Firebase Console project aquacampus-ed284, add Android app $AndroidPackage, and download google-services.json to android\app\."
}

try {
  $json = (Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json)
} catch {
  throw 'google-services.json is invalid JSON.'
}
$foundProject = [string]$json.project_info.project_id
if ($foundProject -ne $ProjectId) {
  throw "WRONG Firebase project: $foundProject. Expected $ProjectId. Build stopped."
}
$matches = @($json.client | Where-Object {
  $_.client_info.android_client_info.package_name -eq $AndroidPackage
})
if ($matches.Count -ne 1) {
  throw "Firebase Android app package $AndroidPackage not found exactly once in google-services.json."
}
$app = $matches[0]
$appId = [string]$app.client_info.mobilesdk_app_id
$senderId = [string]$json.project_info.project_number
$apiKey = [string]$app.api_key[0].current_key

if ([string]::IsNullOrWhiteSpace($apiKey) -or
    [string]::IsNullOrWhiteSpace($senderId) -or
    $appId -notmatch '^1:\d+:android:[0-9a-fA-F]+$') {
  throw 'Missing or malformed Firebase Android app config: API key, app ID, or project number.'
}
Write-Host "Verified Firebase project: $ProjectId; package: $AndroidPackage" -ForegroundColor Cyan

if (-not (Test-Path 'android')) {
  throw 'Android platform directory missing. Run flutter create --platforms=android --project-name aquacampus .'
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
& flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }

$defines = @(
  "--dart-define=FIREBASE_API_KEY=$apiKey"
  "--dart-define=FIREBASE_APP_ID=$appId"
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$senderId"
  "--dart-define=FIREBASE_PROJECT_ID=$ProjectId"
  "--dart-define=FIREBASE_AUTH_DOMAIN=$ProjectId.firebaseapp.com"
)
& flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk --release failed' }
$source = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $source)) { throw 'Expected release APK was not generated.' }
$destDir = Join-Path $PSScriptRoot 'release'
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$destination = Join-Path $destDir 'AQUACAMPUS-FIREBASE-LIVE.apk'
Copy-Item -Path $source -Destination $destination -Force
Write-Host "Android APK ready: $destination" -ForegroundColor Green
Write-Host 'This is a Firebase-CONFIGURED build. Confirm Firestore rules, roles and 2-phone sync before campus deployment.' -ForegroundColor Yellow
