# AQUACAMPUS — Firebase backend for aquacampus-ed284

**Target Firebase project:** `aquacampus-ed284` (the user's existing project)

**Android package name:** `com.example.aquacampus`

**App architecture:** Native Flutter Android screens → Firebase Authentication → Cloud Firestore streams.

**Android registration verified:** the uploaded `google-services.json` belongs to project `aquacampus-ed284` with package `com.example.aquacampus`. Its public Firebase client settings are integrated into `lib/firebase_android_config.dart`, so you do **not** need to register the Android app again or copy that JSON file into the project for compilation. There is no browser control portal, Render API, fake login or simulated water data. A physical water meter is not connected: actual authorised workers enter the tank depth.

## One-time Google account setup

Open the existing [Firebase project overview](https://console.firebase.google.com/project/aquacampus-ed284/overview).

1. **Authentication → Get started → Sign-in method → Email/Password → Enable → Save.**
2. **Firestore Database → Create database**. Select a nearby regional location deliberately and choose **Production mode**. Avoid public/test rules. The default database is `(default)`.
3. **Project settings** (gear icon) → **Your apps** → **Android app**: verify the existing Android app has package `com.example.aquacampus`. Its registration has already been verified using the uploaded Firebase configuration. Don't register another app unless you deliberately change the Android package.
4. **Firebase client config is already integrated:** `lib/firebase_android_config.dart` contains the public Android config values. The original `google-services.json` is not committed. No private service-account credentials are used. Keep the Android app package name unchanged.
5. Run `cd C:\AQUACAMPUS` and `git pull origin main` (preserve any uncommitted local edits). Ensure Node.js is installed; run `npm install -g firebase-tools`.
6. Run `.\SETUP_FIREBASE.ps1`. It authorizes your Google account, checks access to **aquacampus-ed284**, and lists registered Android apps. It does **not** create another project.
7. After reviewing the Firestore rules in this repo, run `.\SETUP_FIREBASE.ps1 -DeployRules` and explicitly type `DEPLOY`. This publishes **only** `firestore.rules` to **aquacampus-ed284** using the authenticated Google account. It does not deploy a website. Confirm the deployed rules in Firestore Database → Rules. Deploying rules overwrites the existing Firestore rules in that project; review before doing this.
8. Run `.\build_apk.ps1 -LiveFirebase`. The script uses the already integrated Firebase Android options, runs Flutter analyze/tests, and builds `release\AQUACAMPUS-FIREBASE-LIVE.apk`. Android build depends on the Flutter and Android SDKs installed on the laptop. Alternatively download the latest successful APK artifact from GitHub Actions.

**Important:** An uploaded `google-services.json` is an app configuration file (not an Admin SDK credential). Never share your Google password, private service-account keys or access/refresh tokens.

## First trusted Admin

The first Admin must be granted from a trusted Firebase account; a new user cannot award themselves privileged access.

1. Install the **Firebase-connected** Android APK. Register the intended administrator's email and choose a strong password **on the mobile app**.
2. In Firebase Console → Authentication → Users, find the new user's **UID**.
3. Firebase Console → Firestore Database → Data → `users` → `<UID>`. Edit the registered user's Firestore profile to set `approved` (boolean) = `true` and `role` (string) = `admin`. Keep `campusId = main`, `email` and the user's UID unchanged.
4. Sign out and back into the Android app. The admin creates real buildings/hostels and tanks, assigns workers/students/wardens/teachers, enters floor/room counts and sets low-water policy thresholds.
5. All other registered users begin as `approved=false`, role `student`. Admin reviews and assigns their correct roles/facilities/rooms.

## Required two-phone acceptance test

- **Admin phone:** create Hostel 1 (actual name, actual resident count), academic building and canteen. Enter their true tank dimensions and daily water policy.
- **Worker phone:** enter an actual measured tank water depth. Verify the Admin's tank card updates without reopening the app.
- **Student phone:** once approved and assigned to a hostel, enter an actual activity and the litres requested; verify the worker receives it in-app.
- **Worker phone:** approve/reject an amount, then confirm supply *after water has physically been delivered*. Verify the student's request status changes.
- **Warden phone:** confirm access is limited to the assigned hostel.
- **Teacher phone:** enter a legitimate building water request or leak location. SOS details are visible to authorized worker/admin accounts, not a public feed.
- **All accounts:** see administrator notices. There are no background push notifications; an alert is displayed while the app is running and Firestore is reachable.
- **Security check:** verify a new unapproved user cannot read campus data, and offline/stale connections cannot report a successful write.

## Build limitations and safety

- The GitHub Actions job now builds an APK with the **verified public Firebase Android client config** already in the Flutter project; Actions secrets are not needed for these public client identifiers. A successful APK build **does not** enable Firebase Authentication or deploy Firestore rules. The first Administrator must still be securely bootstrapped.
- The app stores real human inputs in Firestore, not physical telemetry. There is no tank sensor, remote valve, motor shutdown, water meter or background push system.
- Keep secure rules under version control, review every change and monitor Firebase usage. No charges are requested by this setup; quota restrictions apply on the Spark plan.
- For public distribution and Play Store updates, configure a private persistent Android release signing key; the current repo's default Gradle release config still uses a development signing key.

