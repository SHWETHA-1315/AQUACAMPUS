# Render + Firebase deployment — AQUACAMPUS

## What is hosted where?

- **Android application:** compiled Flutter APK, installed on student/warden/worker/teacher/admin phones. It directly uses Firebase Auth and Firestore.
- **Firebase:** cloud project containing **Authentication + Cloud Firestore**. Firestore is the shared real-time database. Firebase project creation, authentication enablement, database provisioning and security rule deployment must happen in an authenticated Google account.
- **Render:** **Flutter Web companion** of the exact same project, hosted as a static site. This is not a separate backend and is not required to run the Android APK.

The Flutter project already supports Firebase configuration through compile-time Dart defines. **Without them, all modes are local demonstration and no two devices share data.** Do not describe a web deployment as live water telemetry; there are no sensors.

## Firebase project setup

1. On your own computer, install Node.js / Firebase CLI (`npm install -g firebase-tools`). Run `firebase login` and authorize the intended Google account.
2. To create a new project, use `firebase projects:create YOUR_UNIQUE_PROJECT_ID --display-name AQUACAMPUS`, or run `./SETUP_FIREBASE.ps1 -ProjectId YOUR_UNIQUE_PROJECT_ID -CreateProject`. If a project already exists, omit `-CreateProject`.
3. In the Firebase console, turn on **Authentication → Email/Password**.
4. In Firestore Database, create the default database in a region near campus, **production mode**. Do not choose open rules. Choose the region intentionally since moving Firestore later is difficult.
5. Register a **Firebase Web App** under the project. Get Firebase web config: `apiKey`, `appId`, `messagingSenderId`, `projectId`, `authDomain`. Firebase web config values are public identifiers, **not privileged service-account credentials**.
6. From `C:\AQUACAMPUS` run `firebase deploy --only firestore:rules --project YOUR_UNIQUE_PROJECT_ID`. Audit `firestore.rules` before sharing sensitive campus records.
7. Follow `docs/FIREBASE_LIVE_SETUP.md` to promote **one trusted account** to the first Admin in the Firebase console and to test two phones.
8. To build a live mobile APK locally, supply config via PowerShell env vars and run `./build_apk.ps1 -LiveFirebase`. For GitHub Actions builds, use repository Actions secrets from that same Firebase web config, and re-run the APK workflow. See existing guide.

## Deploy the Flutter Web companion on Render

Create a **Render Static Site**, NOT a Render Web Service. Use:
- Git repository: `https://github.com/SHWETHA-1315/AQUACAMPUS`
- Branch: `main`
- Build command: `bash scripts/build_render_web.sh`
- Publish directory: `build/web`
- Name: `aquacampus-web` (or any available name)
- Auto deploy: enabled

Alternatively deploy from root `render.yaml`.

On the Render service, configure environment variables:
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`.

Without **all four required keys** (first four), the site builds local demo mode; it does **not** connect to Firestore. Static Render environment variables are compiled into the public web bundle and must **never** contain secrets, API admin credentials, private keys, or service-account JSON.

For Firebase Auth on web, add the final `<site>.onrender.com` domain to **Authentication → Settings → Authorized domains**. Verify with two accounts and two browsers.

## Run and verify

```powershell
cd C:\AQUACAMPUS
git pull --ff-only origin main
flutter pub get
flutter test
flutter run
```

To test your hosted Web site, register an ordinary account, have the trusted Admin approve it, then submit a water request. Another approved role sees it through Firestore. For the Android release APK, use GitHub Actions artifacts.

**Operational boundary:** SOS messages are visible in authorized **in-app Firestore feeds**, not background push notifications. No water is physically delivered or valves controlled by this software.
