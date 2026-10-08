#!/usr/bin/env bash
# The AQUACAMPUS system is mobile-only.
# Render is not the application's backend; the Android APK uses Firestore.
set -Eeuo pipefail
mkdir -p build/web
cat > build/web/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="robots" content="noindex,nofollow"><title>AQUACAMPUS Mobile App</title></head>
<body><main style="font:16px system-ui;max-width:500px;margin:70px auto;padding:25px">
<h1>AQUACAMPUS</h1><p>This service no longer offers a web application. Campus water operations are available inside the official Android app only.</p>
</main></body></html>
EOF
echo "AQUACAMPUS mobile-only placeholder published."
