# Verification emails not arriving (AQUACAMPUS)

The Android app uses **Firebase Authentication** on project `aquacampus-ed284`.
Its `sendEmailVerification()` call requests a Firebase-managed email.
An accepted request **does not prove delivery to the recipient's inbox**.
No client-side Flutter code can force an email through another mail provider.

## On the Android phone

1. Sign in using the account registered for the correct email address.
   If registration previously created a Firebase login but no Firestore
   profile, use **Restore my account profile** rather than registering again.
2. On Verify email, confirm the exact **Account: ...** address.
3. Check **All Mail**, **Spam**, **Promotions**, and email filters; search for
   `noreply`, `Firebase`, `AQUACAMPUS`, and `verify`.
4. Tap **Resend verification email** **once**. The app indicates whether
   Firebase accepted the request or rejected it with a specific error code.
   Successful return means request accepted, **not delivered**. Do not
   repeatedly tap: the app enforces a 60-second retry cooldown.
5. If a link arrives, open it in browser and return to app. The app refreshes
   verification automatically on resume; **I verified my email · Refresh** also works.
6. You still need campus Admin approval before entering student/staff portals.

## Firebase Console checks (must be done by an actual Firebase project owner)

1. Open the `aquacampus-ed284` Firebase project **Authentication > Sign-in method**
   and make sure **Email/Password** is enabled. The repository includes
   `firebase.json` provider settings, but publishing APKs does **not**
   deploy this cloud configuration.
2. Open **Authentication > Templates > Email address verification**.
   Check the template, sender name/address, action link and any custom domain
   configuration. Use Firebase's default sender first to isolate DNS/SMTP issues.
   If custom SMTP is enabled, verify host, port, authentication, sender address
   and mail provider delivery logs. Do not share SMTP passwords.
3. **Authentication > Settings > Authorized domains**: check domains used by
   the email action links; malformed/unapproved action domains will prevent
   successful verification.
4. Check sending quotas and rate limits; repeated attempts may be throttled.
   See https://firebase.google.com/docs/auth/limits
5. If Firebase says the request succeeded but no inbox receives a message,
   ask the recipient's mail administrator about blocked Firebase sender emails.
   Firebase console may not expose individual delivery status.
6. If Firebase and recipient mail filters have been checked, inspect
   Firebase Authentication-related Google Cloud logs and raise Firebase
   support issue with error code and timestamps (do not send credentials).

**Owner-authorized, read-only cloud config audit:**

```bash
gcloud auth application-default login
python -m pip install google-auth requests
python tools/check_verification_email.py
```

Alternatively, configure `firebase-production` GitHub environment Workload
Identity and manually launch **Diagnose AQUACAMPUS Firebase Verification Email**
with `project=aquacampus-ed284`. The audit reads only the Auth provider,
template, sender mode, custom SMTP/DNS metadata and authorized-domain count.
It does **not** send actual emails or confirm mail receipt. An absent workload
identity prevents a cloud audit, and nothing is changed without owner access.

**Security rule:** never mark `emailVerified=true` manually, set a Firebase
token claim yourself or disable verification merely to bypass missing email.
Admin approval alone is not proof of control of the email address.
