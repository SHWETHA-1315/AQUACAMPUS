# AQUACAMPUS · Set up the EXISTING Firebase project aquacampus-ed284.
# Firebase requires a Google-account sign-in on the device running this script.
# This never creates an additional Firebase project or a sample database.
param(
  [switch]$DeployRules
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$ProjectId = 'aquacampus-ed284'
$AppPackage = 'com.example.aquacampus'

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw 'Firebase CLI not found. Install Node.js and run: npm install -g firebase-tools'
}
firebase --version
if ($LASTEXITCODE -ne 0) { throw 'Firebase CLI could not start.' }

Write-Host "Authorizing your Google account for existing project $ProjectId ..." -ForegroundColor Cyan
firebase login
if ($LASTEXITCODE -ne 0) { throw 'Firebase login failed or was canceled.' }

Write-Host "Checking that this Google account can see $ProjectId ..."
$projects = & firebase projects:list --json
if ($LASTEXITCODE -ne 0) { throw 'Cannot read Firebase project list.' }
$projectData = ($projects | Out-String | ConvertFrom-Json)
$found = @($projectData.result | Where-Object { $_.projectId -eq $ProjectId })
if ($found.Count -ne 1) {
  throw "The signed-in Google account does not have access to $ProjectId. Add it in Firebase Project settings > Users and permissions."
}
Write-Host "Confirmed Firebase project: $ProjectId" -ForegroundColor Green

Write-Host "Registered Android apps in $ProjectId :"
firebase apps:list ANDROID --project $ProjectId
if ($LASTEXITCODE -ne 0) { throw 'Could not query Firebase Android apps.' }

Write-Host ""
Write-Host 'Confirm these two settings in Firebase Console:' -ForegroundColor Yellow
Write-Host '  1. Build > Authentication > Sign-in method > Email/Password: Enabled.'
Write-Host '  2. Build > Firestore Database > (default) database: Created in production mode.'
Write-Host "  3. Project settings > Your apps > Android app package: $AppPackage."
Write-Host 'Download the Android app google-services.json into C:\AQUACAMPUS\android\app\.'
Write-Host 'The Android release build reads that file and refuses the wrong project/app.'
Write-Host ""

if ($DeployRules) {
  $answer = Read-Host "Deploy the local firestore.rules to $ProjectId (overwrites existing Firestore rules)? Type DEPLOY"
  if ($answer -ne 'DEPLOY') {
    throw 'Rule deployment canceled; existing Firebase rules unchanged.'
  }
  firebase deploy --only firestore:rules --project $ProjectId
  if ($LASTEXITCODE -ne 0) { throw 'Firestore rules deployment failed. Review Firebase CLI output.' }
  Write-Host "Firestore rules deployed to $ProjectId" -ForegroundColor Green
} else {
  Write-Host 'Once Firestore exists and rules are reviewed, run:' -ForegroundColor Cyan
  Write-Host '  .\SETUP_FIREBASE.ps1 -DeployRules'
}
Write-Host 'See docs/FIREBASE_LIVE_SETUP.md for first-admin bootstrap and live multi-phone testing.'
