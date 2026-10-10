"""Owner-only, read-only Firebase email-verification configuration audit.

Requires Google Application Default Credentials with firebaseauth.configs.get.
Never prints API keys, SMTP credentials, user emails or tokens.
This does NOT prove that an external mailbox received a message.
"""
import sys

PROJECT = "aquacampus-ed284"
SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]


def run():
    import google.auth
    from google.auth.transport.requests import AuthorizedSession

    credentials, credential_project = google.auth.default(scopes=SCOPES)
    if credential_project and credential_project != PROJECT:
        raise RuntimeError("Wrong Google credentials project selected.")
    session = AuthorizedSession(credentials)
    url = f"https://identitytoolkit.googleapis.com/admin/v2/projects/{PROJECT}/config"
    response = session.get(url, timeout=30)
    response.raise_for_status()
    cfg = response.json()
    email_signin = cfg.get("signIn", {}).get("email", {})
    if email_signin.get("enabled") is not True:
        raise RuntimeError("Email/Password provider is DISABLED in production.")
    print("PASS: Email/Password Authentication provider is enabled.")

    notification = cfg.get("notification", {})
    sending = notification.get("sendEmail", {})
    method = sending.get("method", "METHOD_UNSPECIFIED")
    print(f"Firebase email sending mode: {method}")
    if method == "CUSTOM_SMTP":
        smtp = sending.get("smtp", {})
        if not smtp.get("host") or not smtp.get("senderEmail") or not smtp.get("port"):
            raise RuntimeError("CUSTOM_SMTP configured without required host/sender/port. "
                               "Repair SMTP in Firebase Authentication > Templates.")
        print("CHECK: custom SMTP configured. Test provider access, sender verification, "
              "credentials and spam/DNS configuration separately.")
    elif method in ("DEFAULT", "METHOD_UNSPECIFIED"):
        print("INFO: Firebase-managed email template sender is selected or unspecified. "
              "Check spam, template settings, and daily quota.")
    else:
        raise RuntimeError("Unknown Firebase email sending method. Review project settings.")

    template = sending.get("verifyEmailTemplate", {})
    if not template:
        print("CHECK: verification template not returned by API. Inspect Authentication > Templates.")
    else:
        sender = template.get("senderEmail") or template.get("senderDisplayName")
        if sender:
            print("PASS: verification email template contains sender identification.")
        else:
            print("CHECK: verification email sender is not exposed in template.")
        if template.get("disabled") is True:
            raise RuntimeError("Verification email template appears disabled.")
        print("CHECK: verification email template exists; validate its action URL in Console.")

    domains = cfg.get("authorizedDomains") or []
    print(f"Authorized authentication domains configured: {len(domains)}")
    if not domains:
        print("CHECK: no authorized domains returned; action links may not work.")
    dns_info = sending.get("dnsInfo", {})
    if dns_info.get("useCustomDomain") and not dns_info.get("customDomain"):
        raise RuntimeError("Custom sender domain requested but verification incomplete.")
    if dns_info.get("useCustomDomain"):
        print("CHECK: a custom sender domain is active; verify SPF/DKIM/DMARC.")
    print("CONFIG AUDIT FINISHED. The Android SDK's sendEmailVerification() "
          "acknowledgement is NOT proof of inbox delivery.")


if __name__ == "__main__":
    try:
        run()
    except Exception as exc:
        sys.exit("FIREBASE EMAIL CONFIG AUDIT FAILED: " + str(exc))
