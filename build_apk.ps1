# AQUACAMPUS – build an installable Flutter Android APK on Windows.
# Run from the extracted project folder in PowerShell: .\build_apk.ps1
param([switch]$LiveFirebase)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Run-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter not found on PATH. Install Flutter and Android Studio/SDK first: https://docs.flutter.dev/get-started/install/windows/mobile'
}
if (-not (Test-Path '.\android')) {
    Write-Host 'Generating native Android project...' -ForegroundColor Cyan
    Run-Checked 'flutter' @('create','--platforms=android','--project-name=aquacampus','.')
}
Run-Checked 'flutter' @('pub','get')
Run-Checked 'flutter' @('test')

$buildArgs = @('build','apk','--release')
if ($LiveFirebase) {
    $keys = @('FIREBASE_API_KEY','FIREBASE_APP_ID','FIREBASE_MESSAGING_SENDER_ID','FIREBASE_PROJECT_ID')
    foreach ($key in $keys) {
        $v = [Environment]::GetEnvironmentVariable($key)
        if ([string]::IsNullOrWhiteSpace($v)) { throw "Missing $key environment variable for cloud build." }
        $buildArgs += "--dart-define=$key=$v"
    }
}
Run-Checked 'flutter' $buildArgs
$src = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $src)) { throw "Flutter finished, but APK not found at $src" }
New-Item -ItemType Directory -Force -Path '.\release' | Out-Null
$target = Join-Path $PSScriptRoot 'release\AQUACAMPUS-v1.1-android.apk'
Copy-Item $src $target -Force
Write-Host "APK GENERATED: $target" -ForegroundColor Green
Write-Host 'Note: By default this is offline demo mode. Live multi-device deployment requires Firebase configuration and Firestore rules.' -ForegroundColor Yellow
