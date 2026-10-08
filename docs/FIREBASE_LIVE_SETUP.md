# AQUACAMPUS — Firebase backend for aquacampus-ed284

**Target Firebase project:** `aquacampus-ed284` (the user's existing project)

**Android package name:** `com.example.aquacampus`

**App architecture:** Native Flutter Android screens → Firebase Authentication → Cloud Firestore streams. There is no browser control portal, Render API, fake login or simulated water data. A physical water meter is not connected: actual authorised workers enter the tank depth.

## One-time Google account setup

Open the existing [Firebase project overview](https://console.firebase.google.com/project/aquacampus-ed284/overview).

1. **Authentication → Get started → Sign-in method → Email/Password → Enable → Save.**
2. **Firestore Database → Create database**. Select a nearby regional location deliberately and choose **Production mode**. Avoid public/test rules. The default database is `(default)`.
3. **Project settings** (gear icon) → **Your apps** → **Add app → Android**. Register **exact package name** `com.example.aquacampus`, nickname `AQUACAMPUS Android`. SHA-1 is not required for Firebase Email/Password auth. Do not create a Web app or a duplicate Firebase project.
4. **Download `google-services.json`**, which contains the public Android Firebase project configuration. Place it at **`C:\AQUACAMPUS\android\app\google-services.json`**. Leave the Android app package name unchanged after registering it. This repository's Git ignore excludes the configuration file from Git commits. Never substitute a service-account/private-key JSON.
5. Run `cd C:\AQUACAMPUS` and `git pull origin main` (preserve any uncommitted local edits). Ensure Node.js is installed; run `npm install -g firebase-tools`.
6. Run `.\SETUP_FIREBASE.ps1`. It authorizes your Google account, checks access to **aquacampus-ed284**, and lists registered Android apps. It does **not** create another project.
7. After reviewing the Firestore rules in this repo, run `.\SETUP_FIREBASE.ps1 -DeployRules` and explicitly type `DEPLOY`. This publishes **only** `firestore.rules` to **aquacampus-ed284** using the authenticated Google account. It does not deploy a website. Confirm the deployed rules in Firestore Database → Rules. Deploying rules overwrites the existing Firestore rules in that project; review before doing this.
8. Run `.\build_apk.ps1 -LiveFirebase`. The script reads the correct Android app entry in `google-services.json`, checks both project ID and package, runs Flutter tests and builds `release\AQUACAMPUS-FIREBASE-LIVE.apk`. It refuses missing/mismatched configuration. Android build depends on the Flutter and Android SDKs installed on the laptop.

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

- The **latest GitHub Actions APK job intentionally fails** until valid `FIREBASE_API_KEY`, `FIREBASE_APP_ID` (Android app ID), `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID` are supplied as Actions secrets; this prevents publishing a disconnected APK. The Windows `build_apk.ps1` works from the downloaded Android Firebase config without setting those variables manually.
- The app stores real human inputs in Firestore, not physical telemetry. There is no tank sensor, remote valve, motor shutdown, water meter or background push system.
- Keep secure rules under version control, review every change and monitor Firebase usage. No charges are requested by this setup; quota restrictions apply on the Spark plan.
- For public distribution and Play Store updates, configure a private persistent Android release signing key; the current repo's default Gradle release config still uses a development signing key.

