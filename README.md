# AQUACAMPUS · Flutter Android Mobile App

**A real Flutter / Dart mobile app**, not an HTML website, mockup, screenshot, or wrapper. Designed for a college campus with **five separate roles** and **three facility types**.

## Build the Android APK

**Build:** GitHub Actions compiles and uploads a real Android APK; inspect the latest workflow run for success. The default APK is an offline single-phone demo until Firebase is configured. Never rename a ZIP file to .apk.

On a Windows PC with Flutter + Android SDK, run `./build_apk.ps1` from PowerShell. It generates `release/AQUACAMPUS-v1.1-android.apk` after passing Flutter tests and release build. The included `.github/workflows/android-apk.yml` also builds the installable offline-demo APK when these sources are committed to GitHub and the Actions workflow succeeds.

For **real-time multiple-phone usage**, configure Firebase project, Auth and Firestore Rules first and build with `./build_apk.ps1 -LiveFirebase` after setting the four required `FIREBASE_*` environment variables. The local-demo APK does not sync between devices.

## Implemented flows

| Role | What it can do |
| --- | --- |
| Admin | Add hostels, college blocks, canteens, configure occupancy/floors/restrooms/canteen daily cap, register tanks, review requests, post all-campus/facility announcements, see/resolve SOS, approve members & set roles/hostel/room. |
| Water worker | Enter manual water-height readings, approve/reject litres requested, confirm delivery, see/resolve all SOS incidents. |
| Warden | View only assigned hostel and its requests; request additional water. |
| Student | View assigned hostel & estimated per-person share, plan activities by person/load and litres, send SOS with floor/restroom. |
| Teacher | View college/canteen, request extra water, send location-based emergency SOS. |

The application includes **hostels + college blocks + canteens**, an activity-based daily water planner (forecast from submitted requests, not measured usage), in-app realtime Firestore streams, role-protected backend Firestore rules, hostel water shares, and a **500 L/day canteen cap** enforced through a transaction and Firestore daily-cap validation.

**AUXILIARY caution:** This is a software management system. It cannot sense tank levels, measure actual flow, or turn valves off without physical integration. An SOS is an in-app incident report that worker/admin accounts can see while the app is running. **Push notifications for background/closed apps are NOT included**; FCM and backend push setup are needed. Water saving totals are planning estimates, not independent metering.

## Run now — Offline demo on a real Android phone

This workspace does not have the Flutter/Android SDK, so **an APK has not been compiled**. The Flutter project source files are real, and the GitHub workflow can build an APK after upload.

1. Install Flutter stable and Android SDK on your Windows laptop. `flutter doctor` should show Android toolchain ready.
2. Extract the ZIP, open this folder in VS Code/Android Studio and open a terminal in it.
3. Generate the platform scaffold (needed because the environment creating this archive did not have the Flutter SDK):

   ```bash
   flutter create --platforms=android --project-name aquacampus .
   flutter pub get
   flutter test
   flutter run
   ```

4. Enable USB debugging on your Android phone and connect over USB (or start an Android emulator). The app starts in **LOCAL DEMO MODE** when no Firebase defines are supplied.
5. Choose any of the five roles from the login screen. Each role sees its appropriate workspace. The chosen role is a **demo simulation on one device only**; local events persist on the same device using SharedPreferences.
6. Test the end-to-end workflow: Student → request 4 laundry loads × 5 litres = 20 L; log out → Water Worker → approve 20 L → confirm supply; log out → Admin → post shortage broadcast; Teacher/Student → send SOS; Worker/Admin → see and resolve SOS.

## Enable multi-device real-time backend (Firebase)

This part requires **your own Firebase project**; it cannot work without those credentials. Free-tier limits apply; choose free services as appropriate.

1. In Firebase Console, create an Android app named `org.aquacampus.app` (the package ID created by the Flutter scaffold may default to another ID, so adjust `android/app/build.gradle.kts` / manifest accordingly).
2. Enable **Authentication → Email/Password**.
3. Create **Cloud Firestore**, then deploy the provided `firestore.rules` using Firebase CLI or Console (Firestore Rules).
4. In Firebase Authentication, register the first administrator using the app once (new users initially have `student` / `approved: false`). In Firestore Console, edit that user's `users/{uid}` document: set `approved: true`, `role: 'admin'`, `campusId: 'main'`. **Only the project owner may bootstrap this first admin.** No public admin registration is allowed.
5. In the admin portal create your hostel, college buildings, and canteen with the desired daily cap. Approve subsequent users and assign student/warden facility and room.
6. Firebase app identifiers may be supplied as Dart defines at build time (not service account credentials). Example:

   ```bash
   flutter run \
     --dart-define=FIREBASE_API_KEY=YOUR_WEB_OR_ANDROID_API_KEY \
     --dart-define=FIREBASE_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID \
     --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
   ```

   `FIREBASE_AUTH_DOMAIN` is optional on Android. `Firebase.initializeApp` receives these public project configuration values and uses the Dart/FlutterFire SDK. No service account JSON is required or appropriate inside an app.

7. For Android release builds, build from the same configured project with `flutter build apk --release --dart-define=...` after following the official FlutterFire Android integration setup. If plugin setup requires it for your environment, run `flutterfire configure` and include the platform's `google-services.json`; never upload private keys to a public repo.
8. **Not provided yet:** native/OS push notifications, a backend API for physical valves, automatic sensor readings, passwordless invited staff onboarding, field data validation from a real campus, Firebase deploy to your account. These are not implied by the source.

### Data model and permissions

```
users/{uid}                           # verified role, approval, assigned facility + room
campuses/main/facilities/{id}          # type: hostel | college | canteen
campuses/main/tanks/{id}               # shape, dimensions, manual water height
campuses/main/requests/{id}            # activity, requested / approved litres, status
campuses/main/sos/{id}                 # worker/admin incident feed ONLY
campuses/main/notices/{id}             # college/facility messages
campuses/main/dailyUsage/{day}_{id}     # daily canteen supply tracker
```

Request status: `pending -> approved or rejected -> fulfilled`. Worker marks `fulfilled` only **after physically supplying** water. Canteen delivery uses a Firestore transaction so concurrent app users do not accidentally bypass the daily limit. Firestore Rules also restrict recorded daily use to <= the configured canteen cap.

### Example: 17 cm reading

A rectangular tank with inside dimensions 100 cm × 100 cm × 100 cm, and measured water depth 17 cm contains `100 × 100 × 17 / 1000 = 170 litres`. An **upright cylinder** uses `π × (diameter / 2)^2 × water depth / 1000`. Curved/irregular or horizontal tanks are **not** supported yet. Displayed volumes are estimates and depend on correct measurements.

### Security notes

- `firestore.rules` is essential. A hidden button or Flutter page does **not** secure data without server-enforced rules.
- Cloud sign-ups are student/pending only. Admin assignment and membership approvals are enforced by Firestore Rules.
- SOS list/incident contents are unreadable to non-admin/non-worker users in Firestore (including reporters).
- Sensitive real-world campus student data must not be put into the public GitHub repository; use Firebase Auth and rules.
- Remote push notifications, privacy audit and rate limiting (spam SOS, account enumeration, permission abuse) should be added before institution-wide deployment.
- In-app live updates work when the app is open and Firestore is configured; not the same as background push.

## CI APK builds

`.github/workflows/android-apk.yml` runs `flutter create`, analysis, tests, and a release **local-demo APK** on GitHub Actions after the project is uploaded. Download the APK from a successful run's **Artifacts** section. If you need a cloud-connected APK, configure Firebase defines as secure GitHub Actions variables or manually build it locally.

## Project structure

```
lib/main.dart                  # Native Flutter UI screens + forms + role navigation
lib/campus_store.dart          # Persistent offline repository + Firebase real-time service
lib/water_math.dart            # Tank volume and per-person allocation mathematics
test/water_math_test.dart      # Unit tests
firestore.rules               # Server-side authorisation constraints
.github/workflows/android-apk.yml
pubspec.yaml
```

License: MIT. No web HTML UI is included.


## Live backend and production readiness

See [Firebase live campus setup](docs/FIREBASE_LIVE_SETUP.md) for multi-phone login, secure first-admin bootstrap, Firestore rules, deployment, Android live APK and acceptance testing.

**Recent improvements:** admin-editable hostel occupants / floors / restrooms / canteen cap / low-water threshold / essential-use baseline; automatic in-app low-water warnings, a priority-aware water budget engine and staff-only manual tank-reading audit history. These are software calculations on human-entered data.
