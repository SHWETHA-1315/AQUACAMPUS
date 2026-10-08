# AQUACAMPUS: safely sync C:\AQUACAMPUS Flutter source to SHWETHA-1315/AQUACAMPUS.
param([switch]$Watch, [int]$IntervalSeconds=300)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
if ($root.TrimEnd('\\') -ine 'C:\AQUACAMPUS') {
 Write-Warning "This sync script is running from $root; intended path is C:\AQUACAMPUS."
}
$allowed=@('lib','test','android','ios','assets','.github','.gitignore','README.md','LICENSE','pubspec.yaml','analysis_options.yaml','firestore.rules','firebase.json','RUN_LOCAL.ps1','SYNC_TO_GITHUB.ps1','build_apk.ps1','run_android.ps1','PUSH_TO_GITHUB.ps1','BUILD_APK_README.txt','GITHUB_UPLOAD_GUIDE.md')
function Sync-Now {
 if(-not(Test-Path (Join-Path $root '.git'))){throw 'Git is not set up. Run AQUACAMPUS_ROOT_SETUP.ps1 first.'}
 $origin=(& git -C $root remote get-url origin 2>$null)
 if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'SHWETHA-1315/AQUACAMPUS(\.git)?$') {throw "Wrong Git origin: $origin"}
 $branch=(& git -C $root branch --show-current).Trim()
 if($branch -ne 'main'){throw "Expected main branch, got $branch"}
 $paths=@($allowed | Where-Object {Test-Path (Join-Path $root $_)})
 if($paths.Count -eq 0){throw 'No Flutter project files found to sync.'}
 & git -C $root add -A -- @paths
 if($LASTEXITCODE -ne 0){throw 'git add failed'}
 & git -C $root diff --cached --quiet
 if($LASTEXITCODE -eq 1){
   & git -C $root commit -m ("chore: sync AQUACAMPUS Flutter " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
   if($LASTEXITCODE -ne 0){throw 'Commit failed. Set git config user.name and user.email.'}
 }elseif($LASTEXITCODE -ne 0){throw 'git diff failed'}
 & git -C $root pull --rebase origin main
 if($LASTEXITCODE -ne 0){throw 'git pull failed. Resolve any conflict.'}
 & git -C $root push origin main
 if($LASTEXITCODE -ne 0){throw 'Push failed. Authenticate locally as SHWETHA-1315 with write access.'}
 Write-Host 'SUCCESS: GitHub synced from C:\AQUACAMPUS' -ForegroundColor Green
}
if ($Watch) {
 if ($IntervalSeconds -lt 60){throw 'IntervalSeconds must be at least 60'}
 Write-Host "Sync every $IntervalSeconds seconds. Ctrl+C to stop." -ForegroundColor Cyan
 while($true){try {Sync-Now} catch {Write-Warning $_.Exception.Message}; Start-Sleep -Seconds $IntervalSeconds}
}else{Sync-Now}
