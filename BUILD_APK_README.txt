AQUACAMPUS Android APK build (Windows)
=======================================
This folder contains REAL Flutter/Dart application source.
It does NOT contain a compiled APK yet. Building requires the Flutter SDK,
Android SDK, internet access to fetch dependencies, and a working Java toolchain.

1. Install Flutter stable, Android Studio and the Android SDK.
2. Open PowerShell in this folder.
3. Run:  .\build_apk.ps1
4. After a successful build the installable file is:
   release\AQUACAMPUS-v1.1-android.apk
5. Copy the file to your phone and install it; allow installation from this source.
6. This default APK uses local demo mode. For live multi-user operation,
   set up a Firebase project, Authentication, Cloud Firestore and
   firestore.rules, then supply the four FIREBASE_* environment variables and run:
      .\build_apk.ps1 -LiveFirebase

Alternative cloud builder once project is committed to GitHub:
Repository > Actions > Build Android APK > Run workflow > Artifacts.
The GitHub action builds the default offline-mode APK without Firebase credentials.
