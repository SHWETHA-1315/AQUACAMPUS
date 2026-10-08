# AQUACAMPUS interactive Firebase provisioning on your own Windows machine.
# Requires you to authorize a Google account in browser; no service-account keys needed.
param(
  [Parameter(Mandatory = $true)][string]$ProjectId,
  [switch]$CreateProject,
  [string]$FirestoreRegion = "asia-south1"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw "Install Node.js, then run: npm install -g firebase-tools"
}
Write-Host "Signing in to Firebase in your browser. Use your intended Firebase account." -ForegroundColor Cyan
firebase login
if ($LASTEXITCODE -ne 0) { throw "Firebase login failed." }
if ($CreateProject) {
  Write-Host "Creating new Firebase project $ProjectId ..."
  firebase projects:create $ProjectId --display-name "AQUACAMPUS"
  if ($LASTEXITCODE -ne 0) { throw "Project creation failed; check unique project ID and account quota." }
}
Write-Host "Checking Firebase project $ProjectId ..."
firebase projects:list
if ($LASTEXITCODE -ne 0) { throw "Could not list Firebase projects." }
Write-Host ""
Write-Host "Complete these steps in the Firebase Console, project $ProjectId :" -ForegroundColor Yellow
Write-Host "1. Authentication > Sign-in method > enable Email/Password."
Write-Host "2. Firestore Database > Create database > production mode > choose region (e.g. $FirestoreRegion)."
Write-Host "3. Project settings > Your apps > add a Web app called AQUACAMPUS."
Write-Host "4. Copy that Web app config's apiKey, appId, messagingSenderId, projectId, authDomain."
Write-Host "5. Deploy Firestore rules after database creation using:"
Write-Host "   firebase deploy --only firestore:rules --project $ProjectId"
Write-Host ""
Write-Host "Then follow docs/FIREBASE_LIVE_SETUP.md to register and approve the first admin."
Write-Host "Never paste passwords, service-account JSON or private tokens into public GitHub files." -ForegroundColor Yellow
