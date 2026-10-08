# AQUACAMPUS: one-time first Admin activation using the project owner's ADC.
# Do NOT run until the intended person has registered normally in the Android app.
param([Parameter(Mandatory=$true)][string]$Email)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw 'Install Google Cloud CLI, run gcloud init, then rerun. Owner authentication is mandatory.'
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  throw 'Python 3 not available. Install Python and rerun.'
}
Write-Host 'Sign in with your project owner Google account. No password/OTP is shared with the assistant.' -ForegroundColor Cyan
& gcloud auth application-default login
if ($LASTEXITCODE -ne 0) { throw 'Owner Google credentials were not granted.' }
& python -m pip install --user firebase-admin google-cloud-firestore
if ($LASTEXITCODE -ne 0) { throw 'Could not install Firebase Admin client dependencies.' }
& python tools/bootstrap_admin.py --email $Email
if ($LASTEXITCODE -ne 0) { throw 'No admin privileges were granted.' }
Write-Host 'First approved Admin is ready to manage members inside the Android app.' -ForegroundColor Green
