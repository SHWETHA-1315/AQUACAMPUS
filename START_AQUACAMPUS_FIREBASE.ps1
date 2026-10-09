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
  # Windows PowerShell 5.1 treats redirected native stderr as ErrorRecords.
  # Keep progress messages separate from JSON, and use the process exit code.
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $savedPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $script:FirebaseCli @CommandArgs 2> $stderrPath
    $exitCode = $LASTEXITCODE
    $stderr = [System.IO.File]::ReadAllText($stderrPath)
  } finally {
    $ErrorActionPreference = $savedPreference
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
  }
  if ($exitCode -ne 0) {
    throw "Firebase CLI failed (exit $exitCode): firebase $($CommandArgs -join ' ')$([Environment]::NewLine)$($output | Out-String)$stderr"
  }
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    Write-Host $stderr.TrimEnd()
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
# Prefer npm's native launcher over firebase.ps1 on Windows.
$nativeCli = Get-Command firebase.cmd -ErrorAction SilentlyContinue
if ($nativeCli) {
  $script:FirebaseCli = $nativeCli.Source
} else {
  $script:FirebaseCli = (Get-Command firebase -ErrorAction Stop).Source
}
Write-Host 'A Google login window may open. Authorize the Firebase project owner account.' -ForegroundColor Cyan
& $script:FirebaseCli login
if ($LASTEXITCODE -ne 0) { throw 'Google account authorization canceled; nothing was created.' }

$projectsOutput = RunFirebase -CommandArgs @('projects:list','--json')
$projects = $projectsOutput | ConvertFrom-Json
$visible = @($projects.result | Where-Object { $_.projectId -eq $ProjectId })
if ($visible.Count -eq 0) {
  throw "Signed-in Google account lacks access to Firebase project $ProjectId."
}
Write-Host "Existing Firebase project confirmed: $ProjectId" -ForegroundColor Green

# Reuse the Android app whenever it has already been registered.
$appsOutput = RunFirebase -CommandArgs @('apps:list','ANDROID','--project', $ProjectId,'--json')
$appsResult = $appsOutput | ConvertFrom-Json
$androidApps = @($appsResult.result | Where-Object { $null -ne $_ })
$matches = @($androidApps | Where-Object { $_.packageName -eq $AndroidPackage })
if ($matches.Count -gt 1) { throw 'Multiple Android apps have the same package; cannot select safely.' }
if ($matches.Count -eq 1) {
  $firebaseAppId = [string]$matches[0].appId
  Write-Host "Using existing Android app: $firebaseAppId" -ForegroundColor Green
} else {
  Write-Host "Registering Android app $AndroidPackage in $ProjectId ..."
  $createdOutput = RunFirebase -CommandArgs @('apps:create','ANDROID','AQUACAMPUS Android',
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
RunFirebase -CommandArgs @('apps:sdkconfig','ANDROID',$firebaseAppId,'--project',$ProjectId,'--out',$configPath) | Out-Null
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
$databasesOutput = RunFirebase -CommandArgs @('firestore:databases:list','--project',$ProjectId,'--json')
$databasesResponse = $databasesOutput | ConvertFrom-Json
$dbList = @($databasesResponse.result | Where-Object { $null -ne $_ })
$defaultDatabase = @($dbList | Where-Object { $_.name -match '/databases/\(default\)$' })
if ($defaultDatabase.Count -eq 0) {
  Write-Host "No default Firestore database found. Proposed region: $FirestoreRegion"
  $confirmed = Read-Host "Creating the Firestore database fixes its region permanently. Type CREATE"
  if ($confirmed -ne 'CREATE') { throw 'Firestore database creation canceled.' }
  RunFirebase -CommandArgs @('firestore:databases:create','(default)',"--location=$FirestoreRegion",
     '--project',$ProjectId) | Out-Null
  Write-Host "Created default Firestore database in $FirestoreRegion" -ForegroundColor Green
} else {
  Write-Host 'Existing default Firestore database found. Reusing it.' -ForegroundColor Green
}
if (-not $SkipRuleDeploy) {
  Write-Host 'Firebase deploy will enable Email/Password sign-in and replace Firestore rules.' -ForegroundColor Yellow
  Write-Host 'The deployment target is ONLY the existing aquacampus-ed284 project.'
  $confirmedRules = Read-Host 'Type DEPLOY to enable Auth and deploy strict Firestore access-control rules'
  if ($confirmedRules -ne 'DEPLOY') { throw 'Firebase backend deployment canceled.' }
  RunFirebase -CommandArgs @('deploy','--only','auth,firestore:rules','--project',$ProjectId) | Out-Null
  Write-Host 'Email/Password Authentication and Firestore security rules deployed.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Auth provider: Email/Password is declared in firebase.json and deployed together with Firestore rules.' -ForegroundColor Cyan
Write-Host 'No fabricated accounts or user roles have been created.' -ForegroundColor Yellow
Write-Host 'To build the Android APK run:' -ForegroundColor Cyan
Write-Host '   .\build_apk.ps1 -LiveFirebase'
Write-Host 'Register your real Admin account in the app. Then use Firebase Console or BOOTSTRAP_ADMIN.ps1 to approve only that verified account.'
