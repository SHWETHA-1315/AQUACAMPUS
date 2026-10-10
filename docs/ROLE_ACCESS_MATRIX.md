# AQUACAMPUS — role portals and permissions

AQUACAMPUS uses Firebase Authentication and the Firestore database of
`aquacampus-ed284`. New users start as unapproved Students. The two existing,
verified Admin accounts retain full control. Admins approve and assign each
other user only AFTER registration; users cannot select their own privileged roles.

| Assigned role | Sites and water-demand visibility | Actions in Android app |
| --- | --- | --- |
| Admin 1 / Admin 2 | All campus sites, requests and SOS | Create/edit facilities and tanks, assign member roles, approve/reject requests, log water deliveries, read tank history, close SOS, send notices |
| Water Worker (`worker`) | All campus sites and requests | Enter manual tank readings, approve/reject requests, record deliveries, handle SOS |
| Warden (`warden`) | Exactly the assigned **Hostel** | Hostel/room water demand, request water, see tanks, report SOS, read notices |
| Student (`student`) | Assigned building/hostel requests; can also report academic/canteen leaks | Request water, track own request status, monitor assigned water tanks, report issues |
| Teacher (`teacher`) | College/Canteen locations; own submitted water requests | Request water for teaching and canteen use, view tanks, report water issues |
| College Staff (`staff`) | College/Canteen locations; own submitted water requests | Request and track campus water, view tanks, report issues |
| Canteen Staff (`canteen`) | Exactly the assigned **Canteen** | Kitchen water demand, see canteen-wide requests and tank status, report SOS, read notices |
| Gardener (`gardener`) | Exactly the assigned **Garden** | Request irrigation water, see garden demand and tank readings, report leaking irrigation pipes, read notices |
| Driver (`driver`) | Exactly the assigned **Transport** area | Request vehicle wash water, track transport-area demand and tanks, report water leaks, read notices |

Garden and Transport are new *facility types*. In **Admin → Buildings → Add
campus location**, select **Garden** or **Transport**, give a name and a
water-level warning threshold. The app internally uses a single level and zero
restrooms; it does not require fictitious floor/restroom form inputs.

After creating the locations, open **Admin → People & roles** and select
**Assign / Approve**. Choose the role and matching location. Gardeners require
a Garden; Drivers require a Transport area; Canteen Staff require a Canteen;
Wardens require a Hostel. Students require a valid campus site. Teacher, Staff
and Water Worker can be approved without a fixed site.

The Android role dashboards show role-relevant quick actions. Gardener requests
default to **Garden irrigation**, Driver requests to **Vehicle washing**, and
Canteen Staff requests to **Cooking**. Activities remain editable for real needs.

## Security and deployment

- Firebase Security Rules enforce that assigned personnel cannot create
  requests or file SOS for other roles' sites and cannot approve water requests
  or edit campus/member records.
- Admin role cannot be granted by ordinary clients. Admin-to-Admin role changes
  are protected.
- All roles require email verification **and** Admin approval; permissions
  cannot be claimed on a registration form.
- Security role tests run against a **Firebase emulator**, not the production
  Firebase project.
- **Deploy updated Firestore Rules in `aquacampus-ed284` before using the new
  roles on real phones.** Source code and a built APK do not deploy Firestore
  rules. The authorized Firebase owner can use the repository's
  `firebase-cloud-deploy.yml` workflow or their trusted Firebase CLI.
- Create real Garden/Transport facilities, approve accounts and test with
  multiple phones. Until production deployment and testing succeed, live sync
  and role access cannot be certified.

Existing Admin/Student/Teacher/Warden/Worker roles were not removed.
