# Regression test: no Firebase account or network is used.
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$source = Join-Path $PSScriptRoot '..\START_AQUACAMPUS_FIREBASE.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
  $source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$functionAst = $ast.Find({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'RunFirebase'
}, $true)
if (-not $functionAst) { throw 'RunFirebase function missing' }
. ([scriptblock]::Create($functionAst.Extent.Text))
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
  $script:FirebaseCli = Join-Path $tempDir 'firebase.cmd'
  @'
@echo off
echo - Preparing the list of your Firebase projects 1>&2
echo {"status":"success","result":[{"projectId":"aquacampus-ed284"}]}
exit /b 0
'@ | Set-Content -LiteralPath $script:FirebaseCli -Encoding ASCII
  $json = RunFirebase -CommandArgs @('projects:list', '--json')
  $response = $json | ConvertFrom-Json
  if ($response.result[0].projectId -ne 'aquacampus-ed284') {
    throw 'Progress output contaminated the JSON result'
  }
  if ($ErrorActionPreference -ne 'Stop') { throw 'Caller error preference changed' }
  @'
@echo off
echo Access denied by Firebase 1>&2
exit /b 7
'@ | Set-Content -LiteralPath $script:FirebaseCli -Encoding ASCII
  $caught = $false
  try { RunFirebase -CommandArgs @('projects:list', '--json') | Out-Null }
  catch {
    $caught = $true
    if ($_.Exception.Message -notmatch 'exit 7' -or
        $_.Exception.Message -notmatch 'Access denied') { throw }
  }
  if (-not $caught) { throw 'Nonzero exit code was accepted as success' }
  if ($ErrorActionPreference -ne 'Stop') { throw 'Caller error preference changed on failure' }
  Write-Host 'PASS: stderr progress preserves JSON; CLI failures remain errors.'
} finally {
  Remove-Item -LiteralPath $tempDir -Recurse -Force
}
