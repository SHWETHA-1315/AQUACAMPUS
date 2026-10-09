# AQUACAMPUS — Firebase backend for aquacampus-ed284

## Verified backend source status (October 2026)

- Firebase Android registration matched: `aquacampus-ed284` / `com.example.aquacampus`.
- Email/Password Authentication provider is declared in `firebase.json` and is deployed by `START_AQUACAMPUS_FIREBASE.ps1` using the project owner's own Google sign-in.
- `firestore.rules` includes role-based Admin, Worker, Warden, Student and Teacher policies; tank reading audit, requests and SOS validation.
- A Firebase emulator GitHub Actions workflow passed **12 security rules tests**. This checks rules locally, **not** deployment in the real Firebase project.
- **Live Firebase deployment not yet confirmed.** Authentication enablement, database existence, first Admin approval and two-Android-phone integration still need owner-authorized cloud access.

### Fastest authorized deployment (Windows)

Open an up-to-date local checkout (`C:\AQUACAMPUS`) and double-click `RUN_AQUACAMPUS_SETUP.cmd`. The script prompts for Google owner login, verifies the existing project, reuses the registered Android app, creates Firestore only if the default database does not exist (with confirmation of its permanent location), and deploys **both Authentication Email/Password and Firestore rules** after you type `DEPLOY`. It does **not** create fake data.

After installing the APK, register the real intended Admin email through the app. Then run `./BOOTSTRAP_ADMIN.ps1 -Email real-admin@example.com` on a trusted owner computer (requires the Google Cloud CLI and owner Google login). It verifies both Auth UID and Firestore profile and explicitly asks before granting access. Alternatively, approve that account manually in the Firebase Console.

Security tests: `npm install` then `npm run test:emulator`. These run on local mock identities only and never write to `aquacampus-ed284`.


**Target Firebase project:** `aquacampus-ed284` (the user's existing project)

**Android package name:** `com.example.aquacampus`

**App architecture:** Native Flutter Android screens → Firebase Authentication → Cloud Firestore streams.

**Android registration verified:** the uploaded `google-services.json` belongs to project `aquacampus-ed284` with package `com.example.aquacampus`. Its public Firebase client settings are integrated into `lib/firebase_android_config.dart`, so you do **not** need to register the Android app again or copy that JSON file into the project for compilation. There is no browser control portal, Render API, fake login or simulated water data. A physical water meter is not connected: actual authorised workers enter the tank depth.

## One-time Google account setup

Open the existing [Firebase project overview](https://console.firebase.google.com/project/aquacampus-ed284/overview).

1. **Authentication Email/Password:** `firebase.json` contains `auth.providers.emailPassword=true`, and the owner-authorized setup script deploys it. You can verify the provider on the Firebase Console Authentication → Sign-in method screen.
2. **Firestore Database → Create database**. Select a nearby regional location deliberately and choose **Production mode**. Avoid public/test rules. The default database is `(default)`.
3. **Project settings** (gear icon) → **Your apps** → **Android app**: verify the existing Android app has package `com.example.aquacampus`. Its registration has already been verified using the uploaded Firebase configuration. Don't register another app unless you deliberately change the Android package.
4. **Firebase client config is already integrated:** `lib/firebase_android_config.dart` contains the public Android config values. The original `google-services.json` is not committed. No private service-account credentials are used. Keep the Android app package name unchanged.
5. Run `cd C:\AQUACAMPUS` and `git pull origin main` (preserve any uncommitted local edits). Ensure Node.js is installed; run `npm install -g firebase-tools`.
6. Run `.\SETUP_FIREBASE.ps1`. It authorizes your Google account, checks access to **aquacampus-ed284**, and lists registered Android apps. It does **not** create another project.
7. After reviewing the security rules, run `.\START_AQUACAMPUS_FIREBASE.ps1` or `RUN_AQUACAMPUS_SETUP.cmd`, explicitly typing `DEPLOY`. This applies Email/Password Auth provider configuration **and** Firestore rules to `aquacampus-ed284`. It does not deploy any website. Confirm both in the Firebase Console. Deploying rules overwrites the existing Firestore rules in that project; review before doing this.
8. Run `.\build_apk.ps1 -LiveFirebase`. The script uses the already integrated Firebase Android options, runs Flutter analyze/tests, and builds `release\AQUACAMPUS-FIREBASE-LIVE.apk`. Android build depends on the Flutter and Android SDKs installed on the laptop. Alternatively download the latest successful APK artifact from GitHub Actions.

**Important:** An uploaded `google-services.json` is an app configuration file (not an Admin SDK credential). Never share your Google password, private service-account keys or access/refresh tokens.

## Two trusted, equally privileged Administrators

**Status:** This repository now supports two protected Admin accounts; the real
accounts are NOT activated automatically by installing the APK. Activation
requires the Firebase project owner's cloud authorization and **two distinct,
registered, email-verified accounts**. No one can self-approve.

1. Install the Firebase-connected APK on two phones. Each intended Admin
   registers a **different real email address** in the app. Confirm both email
   verification links; check the exact address displayed on the verification
   screen and the Spam folder if the mail does not arrive.
2. The Firebase owner authorizes deployment to `aquacampus-ed284` and deploys
   `auth,firestore:rules`. An emulator pass or APK build is not production
   deployment. Review existing rules first, because deployment replaces them.
3. Run this on a trusted owner laptop with Google ADC credentials and a working
   `firebase-admin` Python installation:
   ```powershell
   python tools/activate_two_admins.py --email-one "FIRST_REAL_EMAIL" --email-two "SECOND_REAL_EMAIL"
   ```
   The script validates both Firebase Authentication identities, email
   verification, exact matching Firestore user profiles and any existing Admins.
   It then approves the pair atomically (or leaves already-activated profiles
   unchanged). It refuses to replace a third person who is already an Admin.
4. Alternatively, the owner configures the GitHub `firebase-production`
   environment with secure Workload Identity variables
   `FIREBASE_WIF_PROVIDER` and `FIREBASE_DEPLOY_SERVICE_ACCOUNT`, and store
   two **environment secrets** `AQUACAMPUS_ADMIN_ONE_EMAIL` and
   `AQUACAMPUS_ADMIN_TWO_EMAIL` (two registered, verified accounts).
   Manually run **Deploy AQUACAMPUS Firebase Cloud Backend** with
   `project=aquacampus-ed284` and input
   `approve_two_admins=ACTIVATE TWO ADMINS`. The two email addresses must
   not be entered as public workflow inputs. The workflow must pass its
   read-only live audit.
5. Each Admin then signs out/back in. Both Admins can access Members, Buildings,
   Tanks, Requests, SOS, Notices, and water planning. They can assign and
   approve Student/Teacher/Warden/Worker accounts, but **cannot remove their
   fellow Admin or grant a third Admin from the app**. Such account changes
   require trusted Firebase owner action.
6. Run a read-only audit on an owner-authorized computer:
   ```powershell
   python tools/check_production_ready.py --admin-one "FIRST_REAL_EMAIL" --admin-two "SECOND_REAL_EMAIL"
   ```
   This checks the live deployed rules and both active Admin identities. It is
   **not** a substitute for Android real-phone end-to-end tests.

All other members register independently and start as pending Students. Both
Admins can select the correct role and assign their facility/room after the
person's email is verified. Never upload Admin SDK JSON keys or share passwords.

## Acceptance status — not evidence of production completion

- GitHub build and Flutter unit tests verify compilable app code.
- Local Firebase emulator tests verify role/security behavior against mock users.
- The owner-authorized deployment workflow must complete successfully; before
  that the real Firestore rules, Auth provider setup and two Admins are **not confirmed**.
- The optional read-only live audit verifies the deployed rules and both real Admin accounts.
- A separate two-device test is required to establish that a Student request is received
  by a Worker/Admin, updated to fulfilled, that staff tank readings sync instantly,
  that Teacher/Warden scoping works, and that SOS/Notices propagate. No app code
  can confirm email delivery to a real user's inbox.

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

