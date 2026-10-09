"""Read-only production audit for the real AQUACAMPUS Firebase project.

Run on a trusted machine after gcloud auth application-default login, or in
the owner-authorized GitHub environment with workload identity credentials.

This script does not grant roles, create users or change Firestore records.
"""
import argparse
import pathlib
import sys

PROJECT = "aquacampus-ed284"
SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]


def audit(first, second):
    import firebase_admin
    from firebase_admin import auth, firestore
    import google.auth
    from google.auth.transport.requests import AuthorizedSession
    from google.cloud.firestore_v1.base_query import FieldFilter

    emails = [first.strip().lower(), second.strip().lower()]
    if not emails[0] or "@" not in emails[0] or not emails[1] or "@" not in emails[1]:
        raise ValueError("Provide both registered administrator emails.")
    if emails[0] == emails[1]:
        raise ValueError("The two administrators must be distinct accounts.")

    google_credentials, adc_project = google.auth.default(scopes=SCOPES)
    if adc_project and adc_project not in (PROJECT,):
        raise ValueError(f"Wrong Google Cloud credentials project: {adc_project}")
    session = AuthorizedSession(google_credentials)

    auth_config = session.get(
        f"https://identitytoolkit.googleapis.com/admin/v2/projects/{PROJECT}/config",
        timeout=25,
    )
    auth_config.raise_for_status()
    email_auth = auth_config.json().get("signIn", {}).get("email", {})
    if email_auth.get("enabled") is not True or email_auth.get("passwordRequired") is not True:
        raise ValueError("Real Firebase Email/Password Authentication is not enabled.")
    print("PASS: live Firebase Email/Password authentication is enabled.")

    release_url = f"https://firebaserules.googleapis.com/v1/projects/{PROJECT}/releases/cloud.firestore"
    release = session.get(release_url, timeout=25)
    release.raise_for_status()
    ruleset_name = release.json().get("rulesetName")
    if not ruleset_name:
        raise ValueError("No deployed Firestore ruleset was returned by the Firebase Rules API.")
    rules = session.get(f"https://firebaserules.googleapis.com/v1/{ruleset_name}", timeout=25)
    rules.raise_for_status()
    deployed = [f.get("content", "") for f in rules.json().get("source", {}).get("files", [])]
    local = pathlib.Path("firestore.rules").read_text(encoding="utf-8")
    if local not in deployed:
        raise ValueError("DEPLOYED Firestore rules do not match current checked-in rules.")
    print(f"PASS: live Firestore security rules match source ({ruleset_name}).")

    app = firebase_admin.initialize_app(options={"projectId": PROJECT})
    db = firestore.client(app=app)
    resolved_uids = set()
    for admin_number, email in enumerate(emails, start=1):
        account = auth.get_user_by_email(email, app=app)
        if account.disabled or not account.email_verified:
            raise ValueError(f"{email}: Auth account disabled or email not verified.")
        profile = db.collection("users").document(account.uid).get()
        if not profile.exists:
            raise ValueError(f"{email}: user profile is missing.")
        person = profile.to_dict()
        if (person.get("role") != "admin" or person.get("approved") is not True
                or person.get("campusId") != "main" or person.get("email", "").lower() != email):
            raise ValueError(f"{email}: approved Admin role not active or identity mismatch.")
        resolved_uids.add(account.uid)
        print(f"PASS: Admin {admin_number} is enabled, email-verified and approved.")

    active_admins = {
        doc.id for doc in db.collection("users").where(
            filter=FieldFilter("role", "==", "admin")
        ).stream()
        if doc.to_dict().get("approved") is True
    }
    if active_admins != resolved_uids:
        raise ValueError("Approved Admin profiles are not exactly the two requested identities.")
    print("PASS: exactly two approved Admin profiles, no extra approved Admin.")

    for path in ("facilities", "tanks", "requests", "sos", "notices"):
        # Authorization here is project-owner ADC; this is a database connectivity
        # check, NOT proof of Firestore rules from an Android user.
        list(db.collection("campuses/main/" + path).limit(1).stream())
    print("PASS: Firebase Admin SDK can reach each live campus collection.")
    print("SERVER AUDIT PASSED. Two-device UI, authentication email delivery and")
    print("user-scoped Firestore operations must still be tested on real phones.")


def main():
    parser = argparse.ArgumentParser(description="Audit real Firebase rules and two active Admins.")
    parser.add_argument("--admin-one", required=True)
    parser.add_argument("--admin-two", required=True)
    args = parser.parse_args()
    try:
        audit(args.admin_one, args.admin_two)
    except Exception as error:
        sys.exit("PRODUCTION NOT CONFIRMED: " + str(error))


if __name__ == "__main__":
    main()
