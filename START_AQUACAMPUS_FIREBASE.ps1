# AQUACAMPUS — connect EXISTING aquacampus-ed284 to this Android project.
# Runs on the project owner's Windows computer. No token, API key or password is
# sent to ChatGPT; Firebase CLI handles Google's browser authorization.
#
# Run from C:\AQUACAMPUS: powershell -ExecutionPolicy Bypass -File .\START_AQUACAMPUS_FIREBASE.ps1
param(
  [string]$ProjectId = 'aquacampus-ed284',
  [string]$AndroidPackage = 'com.example.aquacampus',
  [string]$FirestoreRegion = 'asia-south1',
  [switch]$SkipRuleDeploy
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function RunFirebase {
  param([string[]]$CommandArgs)
  $output = & firebase @CommandArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Firebase CLI failed: firebase $($CommandArgs -join ' ')$([Environment]::NewLine)$($output -join [Environment]::NewLine)"
  }
  return ($output | Out-String)
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Install Node.js LTS first, then re-run this script.'
  }
  Write-Host 'Installing official Firebase CLI...' -ForegroundColor Cyan
  & npm install --global firebase-tools
  if ($LASTEXITCODE -ne 0) { throw 'Firebase CLI installation failed' }
}
Write-Host 'A Google login window may open. Authorize the Firebase project owner account.' -ForegroundColor Cyan
& firebase login
if ($LASTEXITCODE -ne 0) { throw 'Google account authorization canceled; nothing was created.' }

$projectsOutput = RunFirebase @('projects:list','--json')
$projects = $projectsOutput | ConvertFrom-Json
$visible = @($projects.result | Where-Object { $_.projectId -eq $ProjectId })
if ($visible.Count -eq 0) {
  throw "Signed-in Google account lacks access to Firebase project $ProjectId."
}
Write-Host "Existing Firebase project confirmed: $ProjectId" -ForegroundColor Green

# Reuse the Android app whenever it has already been registered.
$appsOutput = RunFirebase @('apps:list','ANDROID','--project', $ProjectId,'--json')
$appsResult = $appsOutput | ConvertFrom-Json
$androidApps = @($appsResult.result | Where-Object { $null -ne $_ })
$matches = @($androidApps | Where-Object { $_.packageName -eq $AndroidPackage })
if ($matches.Count -gt 1) { throw 'Multiple Android apps have the same package; cannot select safely.' }
if ($matches.Count -eq 1) {
  $firebaseAppId = [string]$matches[0].appId
  Write-Host "Using existing Android app: $firebaseAppId" -ForegroundColor Green
} else {
  Write-Host "Registering Android app $AndroidPackage in $ProjectId ..."
  $createdOutput = RunFirebase @('apps:create','ANDROID','AQUACAMPUS Android',
    '--package-name',$AndroidPackage,'--project',$ProjectId,'--json')
  $created = $createdOutput | ConvertFrom-Json
  $firebaseAppId = [string]$created.result.appId
  if ([string]::IsNullOrWhiteSpace($firebaseAppId)) {
    throw 'Firebase reported Android app creation but did not return an app ID. Inspect Firebase Console.'
  }
  Write-Host "Created Android app: $firebaseAppId" -ForegroundColor Green
}

$configPath = Join-Path $PSScriptRoot 'android\app\google-services.json'
New-Item -ItemType Directory -Force -Path (Split-Path $configPath) | Out-Null
RunFirebase @('apps:sdkconfig','ANDROID',$firebaseAppId,'--project',$ProjectId,'--out',$configPath) | Out-Null
if (-not (Test-Path $configPath)) { throw 'Firebase Android configuration download failed.' }
$config = (Get-Content -Raw -Path $configPath | ConvertFrom-Json)
if ($config.project_info.project_id -ne $ProjectId) { throw 'Downloaded Android config has wrong Firebase project.' }
$client = @($config.client | Where-Object {
  $_.client_info.android_client_info.package_name -eq $AndroidPackage
})
if ($client.Count -ne 1) { throw "Android config does not match package $AndroidPackage." }
Write-Host "Android Firebase configuration saved to $configPath" -ForegroundColor Green

# Firestore region is a permanent database choice. Do not silently create an
# additional database or change the region of an existing database.
$databasesOutput = RunFirebase @('firestore:databases:list','--project',$ProjectId,'--json')
$databasesResponse = $databasesOutput | ConvertFrom-Json
$dbList = @($databasesResponse.result | Where-Object { $null -ne $_ })
$defaultDatabase = @($dbList | Where-Object { $_.name -match '/databases/\(default\)$' })
if ($defaultDatabase.Count -eq 0) {
  Write-Host "No default Firestore database found. Proposed region: $FirestoreRegion"
  $confirmed = Read-Host "Creating the Firestore database fixes its region permanently. Type CREATE"
  if ($confirmed -ne 'CREATE') { throw 'Firestore database creation canceled.' }
  RunFirebase @('firestore:databases:create','(default)',"--location=$FirestoreRegion",
     '--project',$ProjectId) | Out-Null
  Write-Host "Created default Firestore database in $FirestoreRegion" -ForegroundColor Green
} else {
  Write-Host 'Existing default Firestore database found. Reusing it.' -ForegroundColor Green
}
if (-not $SkipRuleDeploy) {
  $confirmedRules = Read-Host 'Deploy Firestore access-control rules to aquacampus-ed284? Type DEPLOY'
  if ($confirmedRules -ne 'DEPLOY') { throw 'Security rules deployment canceled.' }
  RunFirebase @('deploy','--only','firestore:rules','--project',$ProjectId) | Out-Null
  Write-Host 'Firestore security rules deployed.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'IMPORTANT: In Firebase Console enable Authentication > Sign-in method > Email/Password.' -ForegroundColor Yellow
Write-Host 'No fabricated accounts or user roles have been created.' -ForegroundColor Yellow
Write-Host 'To build the Android APK run:' -ForegroundColor Cyan
Write-Host '   .\build_apk.ps1 -LiveFirebase'
Write-Host 'Then register your own account and grant the first Admin role via Firestore Console.'
