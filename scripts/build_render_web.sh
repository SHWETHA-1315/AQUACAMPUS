#!/usr/bin/env bash
# APK distribution only; campus controls remain in Android.
set -Eeuo pipefail
cat releases/AQUACAMPUS-1.0.0.apk.part{1..6} > releases/AQUACAMPUS-1.0.0.apk
test -s releases/AQUACAMPUS-1.0.0.apk
sha256sum --check releases/AQUACAMPUS-1.0.0.apk.sha256
mkdir -p build/web
cp releases/AQUACAMPUS-1.0.0.apk build/web/
sed 's|releases/||' releases/AQUACAMPUS-1.0.0.apk.sha256 > build/web/AQUACAMPUS-1.0.0.apk.sha256
cat > build/web/index.html <<'EOF'
<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="Download the AQUACAMPUS Android app for campus water planning and requests.">
<title>AQUACAMPUS — Android Download</title>
<style>
*{box-sizing:border-box}body{margin:0;min-height:100svh;display:grid;place-items:center;padding:32px 18px;font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#123e57;background:radial-gradient(ellipse at 85% 15%,#bcecff,transparent 55%),linear-gradient(160deg,#f6fdff,#d9f5ff)}
main{width:min(580px,100%);padding:42px 34px;background:#ffffffed;border:1px solid #c6eafa;border-radius:30px;box-shadow:0 24px 80px #0874a31c;position:relative;z-index:1;text-align:center}
.icon{width:74px;height:74px;margin:0 auto 20px;background:linear-gradient(145deg,#47c5ff,#087fc0);border-radius:23px;display:grid;place-items:center;color:white}
.eyebrow{font-size:12px;font-weight:700;letter-spacing:2px;color:#087bb2}h1{font-size:clamp(30px,7vw,42px);letter-spacing:-1.5px;margin:8px 0 14px}p{line-height:1.7;color:#466b80;margin:0 auto 24px;max-width:430px}
.download{display:block;padding:18px 22px;border-radius:16px;background:#007db8;color:white;text-decoration:none;font-weight:750}.download:hover{background:#00669a}a:focus-visible{outline:3px solid #174f73;outline-offset:4px}
.meta{font-size:13px;color:#53768a;margin:14px 0 26px}.chips{display:flex;gap:8px;flex-wrap:wrap;justify-content:center;margin-bottom:24px}.chips span{background:#e9f8ff;border:1px solid #caeafa;border-radius:30px;padding:8px 12px;font-size:12px;color:#28647e}
.status{border-top:1px solid #dceef6;padding-top:22px;text-align:left}.status strong{display:block;font-size:14px;margin-bottom:7px}.status p{font-size:13px;margin-bottom:16px}.links{display:flex;flex-wrap:wrap;justify-content:center;gap:20px;font-size:13px}a{color:#067aaa}.wave{position:fixed;bottom:0;left:0;width:100%;height:26vh;pointer-events:none;opacity:.5}.footer{font-size:12px;color:#608194;margin-top:20px}
@media(max-width:420px){main{padding:30px 22px;border-radius:24px}}
</style></head><body>
<svg class="wave" viewBox="0 0 1440 320" preserveAspectRatio="none" aria-hidden="true"><path fill="#6bd1f7" d="M0 160C240 40 420 280 720 160S1200 40 1440 160V320H0Z"/><path fill="#22b7ee" opacity=".3" d="M0 220C220 320 500 80 780 180S1220 300 1440 180V320H0Z"/></svg>
<main><div class="icon"><svg width="38" height="46" viewBox="0 0 38 46" aria-hidden="true"><path fill="currentColor" d="M19 1C14 10 3 21 3 29a16 16 0 0 0 32 0C35 21 24 10 19 1Z"/><path d="M10 30a9 9 0 0 0 9 9" fill="none" stroke="#1498d0" stroke-width="3" stroke-linecap="round"/></svg></div>
<div class="eyebrow">CAMPUS WATER, IN YOUR HANDS</div><h1>AQUACAMPUS</h1>
<p>Plan water needs, record tank readings and manage campus requests inside one Android app.</p>
<div class="chips"><span>Admin</span><span>Water Worker</span><span>Warden</span><span>Student</span><span>Teacher</span></div>
<a class="download" href="AQUACAMPUS-1.0.0.apk" download="AQUACAMPUS-1.0.0.apk">Download Android APK ↓</a>
<div class="meta">Version 1.0.0 · 51 MB · Android</div>
<div class="status"><strong>Before campus use</strong><p>This APK includes the Firebase Android configuration. Live sign-in, database deployment and first Admin activation are still awaiting verification. It contains no demo campus data.</p><strong>Install on your phone</strong><p>Open the downloaded APK. If Android asks, allow installation from the app you used to download it. Campus operations are available only inside the Android app.</p></div>
<div class="links"><a href="https://github.com/SHWETHA-1315/AQUACAMPUS">Source code</a><a href="AQUACAMPUS-1.0.0.apk.sha256" download>File checksum</a></div>
<div class="footer">Official project download · Development-signed build</div>
</main></body></html>
EOF
echo "AQUACAMPUS Android download page built."
