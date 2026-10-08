# C Drive: C:\AQUACAMPUS

This package contains Flutter source files directly at its root (no AQUACAMPUS-main folder).

To set up using the all-in-one script: put AQUACAMPUS_ROOT_SETUP.ps1 in C:\AQUACAMPUS, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\AQUACAMPUS\AQUACAMPUS_ROOT_SETUP.ps1"
```

This script requires Git and locally authenticated GitHub write access, and installs/updates source files in the root, skipping the old nested folder. With Flutter SDK and Android SDK installed you can build:

```powershell
cd C:\AQUACAMPUS
.\RUN_LOCAL.ps1 -BuildApk
```

**Status:** The files are uncompiled Flutter source until a build succeeds. Firebase deployment is separate.
