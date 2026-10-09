# AQUACAMPUS — Android & Firebase optimization audit

## What was changed

| Area | Optimization | Why it matters |
| --- | --- | --- |
| Flutter rebuilds | Stable MaterialApp and ThemeData; only the authenticated portal subtree listens to CampusStore updates. | Avoids recreating MaterialApp on every Firestore snapshot and preserves Navigator state. |
| Large lists | ScreenBody now uses ListView.builder with per-page PageStorageKey. | Lazily mounts Firestore cards and remembers the page scroll position. |
| Mobile-first UI | Ocean/sky-blue surfaces, readable status widgets and a clearly identified live-sync button. | Keeps the existing visual identity while making cloud reconnect accessible in-app. |
| Cloud connection | Each active Firestore listener tracks its own fresh server snapshot. Writes are blocked if **any** required feed has failed or is showing cached/pending data. | Prevents successful-looking operations when the campus data is stale. |
| Daily accounting | Filter dailyUsage by today's date; re-subscribe at local midnight and upon Android resume if the day has changed. | Avoids downloading historical canteen/hostel day records forever. |
| History bandwidth | Listen to the latest 100 notices and 250 manual tank readings, ordered newest first. | Caps recurring network and memory costs for historical lists. Older audit documents remain stored in Firestore; use paginated history if full archive access is later required. |
| Tank visibility | Compute the permitted facility-ID set once per call instead of nested repeated scans. | Reduces list filtering overhead for students and teachers. |
| Water accuracy | Mark partial/unmeasured facilities clearly and block shortage predictions or low-water alerts until **all registered tanks** have actual worker readings. | Avoids treating missing measurements as zero or presenting unreliable forecasts. |
| User inputs | Reject nonfinite amounts, invalid tank dimensions, unauthorized/unassigned locations, oversized notices and malformed water requests before writing. | Prevents server rejections and incorrect totals. |
| Identity | User accounts require genuine Firebase email verification before access; Firestore rules check `request.auth.token.email_verified` and role. | Limits access to approved, email-verified campus members. |
| Admin safety | Prevents Admin self-role edits, on both app and Firestore rules. | Reduces accidental self-lockout. |
| Recovery | In-app reconnect, on-resume listener recovery, password reset and resend email verification. | Better resilience to poor campus mobile connectivity. |
| Tests | Firestore emulator tests cover role permissions, private data, audit integrity, daily caps, forged requests and unverified accounts; new unit tests cover partial tank measurements. | Detects regressions before APK generation and rule deployment. |

## Data model and functional boundaries

- **Source of truth:** Firebase Authentication + Cloud Firestore in `aquacampus-ed284`, using only real registered users and human-entered records.
- **App:** Flutter Android APK only. No separate staff website or fake-mode backend.
- **Tank levels:** workers manually measure height with a dipstick. Automatic sensors, valves, pumps, and real push notifications **are not present**.
- **Offline:** the app does not create local unsynchronized campus writes. Reconnect to use live records.
- **Low-water warning:** a calculated in-app warning from configured thresholds; not a certified safety control.
- **Firestore rule tests:** emulator results verify security logic, **not** live cloud rules deployment.

## Verify before campus rollout

1. Enable Email/Password Authentication, create the production Firestore database, and deploy this repository's `firestore.rules` to Firebase project `aquacampus-ed284` with owner credentials.
2. Register and verify the first real user, then authorize their Admin role using the owner-only bootstrap process.
3. Install the **latest successful Android APK** on at least two devices and check role-specific isolation and real-time tank/request/notice updates.
4. Test intermittent connections, midnight accounting, missing tank measurements, Firebase permission-denied errors, and actual manual worker confirmations.
5. Configure production Android release signing and upload App Bundle / Play integrity settings before broad distribution.

## Performance-measurement caveat

Improved query shape and widget mounting are concrete source changes. No stopwatch, Firebase billing metrics, profiler traces, cold-start measurements, or two-phone field benchmarks have been captured yet. Do not interpret source-level optimizations as proof of a measured latency or battery-consumption improvement.
