# AQUACAMPUS — Android Campus Water Management

AQUACAMPUS is a Flutter **Android mobile application** with five role-based portals: Admin, Water Worker, Hostel Warden, Student and Teacher.

**Selected backend:** Firebase project [`aquacampus-ed284`](https://console.firebase.google.com/project/aquacampus-ed284/overview). **Android package:** `com.example.aquacampus`. The Firebase project has been selected in the code, but account-managed Authentication, Firestore creation and rules deployment must be confirmed before a live APK can be released.

The mobile app uses Firebase Authentication and Cloud Firestore as the backend. It has no simulation mode: there is no shortcut for logging in as an admin, and all campus facilities, tank readings, requests, supply confirmations and SOS incidents must be entered by authorised users.

## User workflows

- Admin creates hostels, academic buildings, canteens and tank details; approves and assigns members; sets water policies and publishes notices.
- Worker enters **manual water-height readings**, approves requests, confirms delivered water and resolves leaks.
- Warden monitors the assigned hostel and submits requests.
- Student sends actual daily water requirements and SOS reports.
- Teacher submits campus water requests and reports facility leaks.

Changes are shared to authorised accounts using Firestore real-time listeners. Tanks cannot measure themselves, and the app cannot automatically control pumps or physical water flow.

## Deployment requirement

The app **must** be connected to a real Firebase project. Until that configuration exists, the mobile UI shows a blocking connection-required screen rather than granting simulated access.

Set up the Firebase project, Email/Password Authentication, Firestore database, and deploy [Firestore security rules](firestore.rules). Register an Android application matching the package ID and supply the appropriate Firebase Android app configuration at build time. Bootstrap the first real admin in Firebase Console.

See [Firebase live setup](docs/FIREBASE_LIVE_SETUP.md).

**Simplified build:** Download the Firebase **Android** app's `google-services.json` from the project settings into `android/app/google-services.json`, then run `./SETUP_FIREBASE.ps1 -DeployRules` (after verifying database/rules) and `./build_apk.ps1 -LiveFirebase`. The build script extracts Android Firebase config and checks the project/package automatically.

**GitHub Actions APK:** Build with an authenticated Android Firebase configuration. Never distribute a locally simulated release as the production campus app.

## Visual design

The app uses **sky blue, ocean blue, white, Flutter-drawn wave panels**, accessible cards and navigation, and user-entered water information. No browser interface is required to manage the campus once the backend is configured.

## Run on Windows

```powershell
cd C:\AQUACAMPUS
git pull --ff-only origin main
flutter pub get
flutter test
```

Supply Firebase settings as outlined in the setup guide before producing and installing an Android APK. Do not commit passwords, service-account private keys or security tokens.
