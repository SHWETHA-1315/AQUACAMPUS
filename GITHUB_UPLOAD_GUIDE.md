# Upload AQUACAMPUS Flutter source and produce an APK

Repo: https://github.com/SHWETHA-1315/AQUACAMPUS

## Easiest — upload & trigger GitHub Actions APK build

1. Extract the ZIP into one folder (the folder containing `pubspec.yaml`, `lib/`, `.github/`).
2. Ensure Git for Windows is installed and sign in as **SHWETHA-1315** on GitHub.
3. In PowerShell, `cd` to that folder and run `./PUSH_TO_GITHUB.ps1`.
4. The script clones the existing `main` branch, copies the Flutter sources, commits and pushes to the repo (preserving commit history).
5. Open https://github.com/SHWETHA-1315/AQUACAMPUS/actions and check **Build AQUACAMPUS Android APK**.
6. On a successful run, download the artifact `AQUACAMPUS-Android-APK`. Unzip the artifact to obtain `app-release.apk` (installable Android package).

**This is a real Flutter APK build — not an HTML wrapper.** The repo's first CI APK will be a **LOCAL DEMO** (no cross-device sync). Real multi-device data sharing requires Firebase configuration, proper Firestore rules, and rebuilding with correct configuration. Push notifications when apps are closed are not yet implemented.

## Why source isn't already on GitHub

The ChatGPT GitHub integration successfully verified repository access but GitHub rejected its contents write operation with HTTP 403 (`Resource not accessible by integration`). The above manual push uses your own GitHub login to complete the upload.

## Local build alternative

Install Flutter and the Android SDK, run `flutter create --platforms=android --project-name aquacampus .`, then `flutter pub get`, `flutter test`, and `flutter build apk --release`. The resulting file should be `build/app/outputs/flutter-apk/app-release.apk`.
