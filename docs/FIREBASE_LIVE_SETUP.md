# AQUACAMPUS — enable real multi-phone sync (Firebase Spark)

No APK can run in sample mode. AQUACAMPUS must be compiled with valid Firebase Android app values; otherwise it displays a blocking connection-required screen. For campus-wide operation, create and configure your own Firebase project. This guide does **not** ask you to upload secrets or passwords into a public GitHub repository.

## 1. Create the backend
1. Open Firebase Console, create a Firebase project for AQUACAMPUS and keep its project ID.
2. Enable **Authentication → Sign-in method → Email/Password**.
3. Create **Cloud Firestore** in a nearby region. Use secured rules, **never test/open rules for production**.
4. Register a Firebase **Android app** (package: `com.example.aquacampus`) to obtain the public configuration fields `apiKey`, `appId`, `messagingSenderId`, `projectId` and optional `authDomain`. The Flutter Android app uses explicit `FirebaseOptions`; use the Android app ID (containing `:android:`), not a Web app ID. Never embed Admin SDK credentials or service-account keys.
5. Install Firebase CLI: `npm install -g firebase-tools`; run `firebase login`, then `firebase use --add` from the repo root. Deploy: `firebase deploy --only firestore:rules`.
6. Keep `firestore.rules` identical to your app's schema, including `tankReadings`. Any future rule changes must be deployed separately; APK builds do not deploy backend rules automatically.

## 2. Create the first Admin securely
1. Build/run with live Firebase settings, then register a new account using the actual admin email and a strong password. It is created with `role: student` and `approved: false` by default. This is intentional; end users cannot select privileged roles.
2. In **Firebase Authentication**, locate that user's UID.
3. In **Cloud Firestore → users → <same UID>**, find their profile created during registration. Using the trusted Firebase Console, update only this person's profile to:
   - `approved` (boolean): `true`
   - `role` (string): `admin`
   - `campusId` (string): `main`
   - `facilityId` (string): empty
   - `room` (string): empty
   - Keep their actual `email`, `name`, `createdAt` values.
4. Sign out/in as the Admin. Admin can add locations and tanks, approve other members, assign their roles/rooms and view staff-only SOS reports.
5. **Do not publish** Auth passwords, Admin service-account JSON, private keys or Firebase tokens in GitHub. Config's browser API key is not an Admin credential; protect Firestore with rules.

## 3. Compile a LIVE Android APK

Set environment variables on your own Windows laptop (substitute your *Firebase app's public config*, not a service account):

```powershell
cd C:\AQUACAMPUS
$env:FIREBASE_API_KEY = "your-web-api-key"
$env:FIREBASE_APP_ID = "your-firebase-app-id"
$env:FIREBASE_MESSAGING_SENDER_ID = "your-project-sender-id"
$env:FIREBASE_PROJECT_ID = "your-firebase-project-id"
$env:FIREBASE_AUTH_DOMAIN = "your-project-id.firebaseapp.com"
.\build_apk.ps1 -LiveFirebase
```

Or add the four required values as **GitHub repository Actions secrets**, enable the optional `FIREBASE_AUTH_DOMAIN` secret, and use the latest APK-build workflow. Successful Actions runs expose an **AQUACAMPUS-Android-APK** artifact. A LIVE build is only as secure as the deployed Firestore rules.

## 4. End-to-end real-time acceptance test

On two distinct Android phones signed in as different **approved** accounts, using the **same live Firebase project**:

1. Worker updates tank reading 17 cm; both authorized screens update the litres estimate.
2. Student assigned to Hostel A sends 4 laundry loads × 5 L = 20 L.
3. Worker/admin sees the request in real time, approves 20 L, and *after physical supply* confirms delivery.
4. Admin adjusts canteen daily cap and a hostel's low-water threshold; wardens/students see updated values.
5. Student submits a restroom pipe burst SOS with building/floor; only Admin and Worker can read its details. Reporter/warden/teacher cannot read the SOS feed.
6. Admin posts a 500 L shortage notice for the entire campus; approved users see it in the app.
7. Worker records a new reading below the threshold; members see an **in-app** low-water alert. Staff can view reading history.

## Important limitations
- Staff enter dipstick/scale readings manually; the software cannot measure physical volume without equipment.
- Physical delivery is confirmed by workers; no valve or pump is switched off by the app.
- This implementation has Firestore in-app realtime streams, **not Firebase Cloud Messaging push notifications**. Background/closed-app alerts need a separate authenticated push delivery backend and OS notifications permission.
- The default `campusId` is `main`; multi-institution tenancy is **not** implemented.
- Demo mode allows simulated roles for demonstration and **must not** be used for real authentication.
