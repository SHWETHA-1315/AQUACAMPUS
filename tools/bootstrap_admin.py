"""One-time privileged admin approval using *owner-authorized* Google ADC.
No service-account JSON is committed and no dummy user is created.

Prerequisites:
  python -m pip install firebase-admin google-cloud-firestore
  gcloud auth application-default login
  python tools/bootstrap_admin.py --email REAL_REGISTERED_EMAIL

For use only by the Firebase project owner/admin on a trusted computer.
"""
import argparse
import sys

PROJECT = "aquacampus-ed284"

def main():
    parser=argparse.ArgumentParser(description="Approve the first real AQUACAMPUS Admin")
    parser.add_argument("--email", required=True, help="Email already registered in AQUACAMPUS")
    args=parser.parse_args()
    email=args.email.strip().lower()
    if not email or "@" not in email:
        parser.error("Provide a valid registered email")
    try:
        import firebase_admin
        from firebase_admin import auth, firestore
    except ImportError:
        sys.exit("Install dependencies: python -m pip install firebase-admin")
    try:
        app = firebase_admin.initialize_app(options={"projectId": PROJECT})
        person = auth.get_user_by_email(email, app=app)
        db = firestore.client(app=app)
        ref = db.collection("users").document(person.uid)
        snap = ref.get()
        if not snap.exists:
            sys.exit("STOP: Auth account exists but Firestore profile is missing. Register through the app first.")
        profile = snap.to_dict()
        if profile.get("email", "").lower() != email or profile.get("campusId") != "main":
            sys.exit("STOP: Account identity or campus does not match. No changes made.")
        print(f"Firebase project: {PROJECT}")
        print(f"Verified registered email: {email}")
        print(f"Verified Firebase UID: {person.uid}")
        print(f"Current role: {profile.get('role')}, approved: {profile.get('approved')}")
        if profile.get("role") == "admin" and profile.get("approved") is True:
            print("Already an approved admin. No writes needed.")
            return
        typed = input(f"Type BOOTSTRAP {person.uid} to grant this verified account Admin: ").strip()
        if typed != f"BOOTSTRAP {person.uid}":
            sys.exit("Canceled. No role changed.")
        ref.update({
            "approved": True,
            "role": "admin",
            "facilityId": "",
            "room": "",
        })
        print("Admin access approved successfully. Reopen/sign in on AQUACAMPUS.")
        print("No other accounts were changed.")
    except Exception as exc:
        sys.exit("Admin bootstrap FAILED: " + str(exc))

if __name__ == "__main__":
    main()
