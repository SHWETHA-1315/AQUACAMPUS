# AQUACAMPUS — Android Campus Water Management

## Android download on Render

The Render service publishes an APK download page only; it has no campus control portal. `scripts/build_render_web.sh` checks the release checksum and copies the APK into the static output. No Firebase secrets or Flutter Web build are needed for distribution. The APK is version 1.0.0, development-signed, and includes the registered Firebase Android configuration. Live Firebase deployment and first Admin activation remain pending verification; publishing this download does not complete those steps.

AQUACAMPUS is a Flutter **Android mobile application** with five role-based portals: Admin, Water Worker, Hostel Warden, Student and Teacher.

**Selected backend:** Firebase project [`aquacampus-ed284`](https://console.firebase.google.com/project/aquacampus-ed284/overview). **Android package:** `com.example.aquacampus`. The registered Android client configuration from Firebase has now been integrated into `lib/firebase_android_config.dart`. Account-managed Authentication, Firestore creation and rules deployment still need confirmation before live user workflows can operate.

The mobile app uses Firebase Authentication and Cloud Firestore as the backend. It has no simulation mode: there is no shortcut for logging in as an admin, and all campus facilities, tank readings, requests, supply confirmations and SOS incidents must be entered by authorised users.

## Dual-admin production readiness

The Android build supports **two equally privileged, separate Admin accounts**.
Both can manage campus buildings, tanks, workers, students, teachers, wardens,
water requests, SOS reports and notices. Other roles are permission-restricted.

Two Admin profiles must be **real, distinct, registered, email-verified**
Firebase users on `aquacampus-ed284`; the GitHub source does not secretly
create or grant users. The project owner must explicitly authorize deployment
and run `tools/activate_two_admins.py` to activate both accounts. Admin
promotion and demotion are blocked in the mobile client and Firestore rules to
prevent a takeover. Both Admin accounts remain protected.

The `firebase-production` GitHub workflow deploys rules and supports a
two-email/confirmation owner-authorized bootstrap. The read-only
`tools/check_production_ready.py` audit checks actual production rule
contents and both approved Admin identities; emulator tests are **not**
production verification. See [Firebase live setup](docs/FIREBASE_LIVE_SETUP.md).

**Verified separately:** CI Flutter/static analysis, Android APK compilation,
Firebase emulator role-security tests. **Not automatically verified:** live
Firebase owner deployment, two real Admin activations, Firebase email delivery,
two-phone real-time synchronization and manual water delivery. Do not claim
these are completed until checked.

## User workflows

- Admin creates hostels, academic buildings, canteens and tank details; approves and assigns members; sets water policies and publishes notices.
- Worker enters **manual water-height readings**, approves requests, confirms delivered water and resolves leaks.
- Warden monitors the assigned hostel and submits requests.
- Student sends actual daily water requirements and SOS reports.
- Teacher submits campus water requests and reports facility leaks.

Changes are shared to authorised accounts using Firestore real-time listeners. Tanks cannot measure themselves, and the app cannot automatically control pumps or physical water flow.

## Deployment requirement

The app **must** be connected to a real Firebase project. Firebase Android client settings are compiled into the app; when Firebase cannot initialize, the mobile UI blocks usage rather than granting simulated access.

Set up the Firebase project, Email/Password Authentication, Firestore database, and deploy [Firestore security rules](firestore.rules). The Firebase Android application was registered with the correct package name, and its public Firebase client settings are already included in source code. Bootstrap the first real admin in Firebase Console.

See [Firebase live setup](docs/FIREBASE_LIVE_SETUP.md).

**Simplified build:** GitHub Actions runs `flutter build apk --release` with the registered Firebase Android client settings. Locally, after `git pull`, run `./build_apk.ps1 -LiveFirebase`. You no longer need to upload or copy `google-services.json` to compile. A successfully compiled APK is **not** proof that Firestore rules have been deployed or sign-in enabled.

**GitHub Actions APK:** Builds a genuine Android APK that initializes the existing Firebase project. This is a development-signed APK; set up secure release signing before distributing as a production app. No dummy dataset is shipped.

## Visual design

The app uses **sky blue, ocean blue, white, Flutter-drawn wave panels**, accessible cards and navigation, and user-entered water information. No browser interface is required to manage the campus once the backend is configured.

## Run on Windows

```powershell
cd C:\AQUACAMPUS
git pull --ff-only origin main
flutter pub get
flutter test
```

Project ID, app ID, sender ID, and Firebase client API key are **public Android client identifiers**, not privileged service-account credentials; they are shipped in the APK. Firebase Auth, Firestore Rules, Google API-key restrictions and optionally App Check must protect the backend. Do not commit passwords, service-account private keys or security tokens.
