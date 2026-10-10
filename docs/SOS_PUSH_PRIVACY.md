# SOS siren, private updates and remote push status

## What works in the Android client

- Only a **verified, approved Water Worker** receives the **looping SOS siren**.
  When the Firestore live incident feed contains a new unresolved SOS, Android
  starts a media-playback **foreground service** and a persistent notification.
  It uses the phone's default alarm ringtone; the user can silence it by
  tapping **SILENCE WORKER SIREN** in the SOS page or **Silence my
  SOS siren** in **My alerts**. The lock-screen notification opens the app,
  but cannot silence the alarm without a worker signing in. This silences already-received
  SOS IDs on **that worker phone**; **new SOS IDs will ring again**.
- The SOS is still shown to both authorized Admins and workers. Admins do not
  get the siren. Non-operators may view **only their own SOS reports**.
- Separate FCM registration stores each signed-in person's device token in
  the private Firestore collection `users/{uid}/devices`. Token access is
  locked to that same user; the trusted server uses Admin SDK permissions.
- Live Firestore subscriptions create local Android notifications for relevant
  updated statuses, tank readings and announcements while the app is running,
  and a private per-account alert history under **My alerts**.
- Personal request and SOS contents are not placed in system notifications.
  Notices addressed to a different campus site cannot be read. Private
  requests cannot be read by other residents/wardens/canteen/garden/transport
  staff, **even if they share the same facility**. Admin/Water Worker need
  operational visibility to respond.
- Background remote notification delivery requires the **trusted push sender**
  below. It is **not** activated by installing an APK.

## Deployment: sender is NOT active by default

`functions/index.js` contains scoped server-side Firestore triggers and
Firebase Cloud Messaging routing. It sends **generic** notification text
to only verified role/scope recipients determined from live Firestore profiles,
with a private `users/{uid}/inbox` document. This is not a client-side API key
sender: never send FCM messages with privileged credentials from Flutter.

**Important:** Deploying Firebase Cloud Functions requires a billing-linked
**Blaze** plan according to Firebase pricing. The project was using the
no-card **Spark** plan; this backend was **not deployed**, and push cannot be
claimed to work while the app is closed. Only the authorized Firebase owner
can change billing, approve production deployment and run:

```bash
cd AQUACAMPUS
npm install --prefix functions
npx firebase-tools deploy --project aquacampus-ed284 --only functions
```

First deploy the updated `firestore.rules` to production with owner
authorization. Never use the emulator output as proof of a live deployment.
After deployment, verify FCM on **two Android phones**: submit an SOS from
Student, check Worker alarm/background notification, silence on Worker,
submit a second SOS and confirm that it sounds again; check another student's
inbox/request remains unreadable. Notification permission must be enabled
on Android 13+, and battery-saver/Do Not Disturb can limit ringtone and
foreground-service behavior. A force-stopped app cannot receive FCM until
opened. No mobile operating system can promise an uninterruptible alarm under
all conditions.

## Privacy guarantees and limitations

- Do not place emails, names, assigned rooms, private request notes or SOS
  descriptions in FCM payloads, notification inbox records or Android lock-screen
  previews; only generic messages are sent.
- Local alert history is **per account** in Android private app storage. A user
  switching to a different login sees that other account's private history.
  Android device owners with root/backup access may still read local data.
- Other registered users may still view **shared campus infrastructure
  information**, such as facility names and tank levels. For strict
  cross-department confidentiality, tank/facility Firestore access needs an
  additional security/data-model migration.
- Admins and workers must access the minimum necessary member/request details
  to assign duties and respond to SOS; absolute confidentiality from Admins
  is inconsistent with those workflows.
- A locally-triggered alert works only when its live Firestore listener is
  active. Remote pushes require owner-authorized Functions deployment and
  depend on network and Android notification settings.
