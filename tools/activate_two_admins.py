"""Activate exactly two real, verified AQUACAMPUS administrator accounts.

This is a privileged, project-owner-only operation. It never creates Firebase
Authentication users or bypasses email verification, and it will not demote an
existing administrator to make room for someone else.

Local (owner's trusted computer):
  gcloud auth application-default login
  pip install firebase-admin google-cloud-firestore
  python tools/activate_two_admins.py --email-one FIRST --email-two SECOND

CI (owner-authorized workload identity):
  python tools/activate_two_admins.py --email-one FIRST --email-two SECOND \
    --confirm-one FIRST --confirm-two SECOND
"""
import argparse
import sys

PROJECT_ID = "aquacampus-ed284"
CAMPUS_ID = "main"


def activate(args):
    one = args.email_one.strip().lower()
    two = args.email_two.strip().lower()
    if not one or not two or "@" not in one or "@" not in two or one == two:
        raise ValueError("Provide two DIFFERENT, registered administrator emails.")
    if bool(args.confirm_one) != bool(args.confirm_two):
        raise ValueError("Both confirmation emails must be supplied together.")
    if args.confirm_one or args.confirm_two:
        if (one, two) != (args.confirm_one.strip().lower(), args.confirm_two.strip().lower()):
            raise ValueError("Confirmation emails do not match; no access changed.")
    else:
        confirmation = input("Type ACTIVATE TWO ADMINS to proceed: ").strip()
        if confirmation != "ACTIVATE TWO ADMINS":
            raise ValueError("Canceled. No accounts changed.")

    try:
        import firebase_admin
        from firebase_admin import auth, firestore
        from google.cloud.firestore_v1.base_query import FieldFilter
    except ImportError as exc:
        raise RuntimeError("Install firebase-admin and google-cloud-firestore first.") from exc

    app = firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
    db = firestore.client(app=app)
    members = []
    for addr in (one, two):
        person = auth.get_user_by_email(addr, app=app)
        if not person.email_verified or person.disabled:
            raise ValueError(f"{addr}: email must be verified and account enabled. No changes made.")
        ref = db.collection("users").document(person.uid)
        snap = ref.get()
        if not snap.exists:
            raise ValueError(f"{addr}: Firestore member profile is missing. Register using the app.")
        data = snap.to_dict()
        if (str(data.get("email", "")).strip().lower() != addr
                or data.get("campusId") != CAMPUS_ID):
            raise ValueError(f"{addr}: Firebase Auth and campus profile identity do not match.")
        members.append((person, ref, snap, data))

    if members[0][0].uid == members[1][0].uid:
        raise ValueError("Both emails resolve to one account.")

    target_ids = {members[0][0].uid, members[1][0].uid}
    existing = db.collection("users").where(
        filter=FieldFilter("role", "==", "admin")
    ).stream()
    for snapshot in existing:
        if snapshot.to_dict().get("approved") is True and snapshot.id not in target_ids:
            raise ValueError(
                "A different administrator is already active. "
                "Refusing to demote or replace this person automatically."
            )

    # Atomic: neither admin becomes active if the other profile was changed.
    batch = db.batch()
    changed = 0
    for person, ref, snap, profile in members:
        if profile.get("role") == "admin" and profile.get("approved") is True:
            continue
        batch.update(
            ref,
            {"role": "admin", "approved": True, "facilityId": "", "room": ""},
            option=db.write_option(last_update_time=snap.update_time),
        )
        changed += 1
    if changed:
        batch.commit()

    for addr, (person, ref, _, _) in zip((one, two), members):
        refreshed = ref.get().to_dict()
        if not refreshed or refreshed.get("approved") is not True or refreshed.get("role") != "admin":
            raise RuntimeError(f"Post-write verification failed for {addr}.")
    print(f"SUCCESS: two verified full-control administrators activated on {PROJECT_ID}.")
    print(f"Admin 1: {one}")
    print(f"Admin 2: {two}")
    print(f"Profiles changed: {changed}; no third admin was created.")
    print("Sign out/sign back in on both Android devices to refresh the role.")


def main():
    parser = argparse.ArgumentParser(description="Activate two verified AQUACAMPUS admins safely.")
    parser.add_argument("--email-one", required=True)
    parser.add_argument("--email-two", required=True)
    parser.add_argument("--confirm-one", default="")
    parser.add_argument("--confirm-two", default="")
    args = parser.parse_args()
    try:
        activate(args)
    except Exception as exc:
        sys.exit("Two-admin activation FAILED: " + str(exc))


if __name__ == "__main__":
    main()
