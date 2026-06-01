"""Seed focused demo data for the apply -> accept loop.

Builds everything around the two dev-bypass demo accounts (DEV_WORKER_PHONE /
DEV_EMPLOYER_PHONE) so a presenter can log in as either and immediately show:

  * Employer: jobs with pending applicants ready to accept/reject, one job that
    flips open -> assigned on the final accept, and one empty job to apply to live.
  * Worker: pending applications plus one already-accepted job.

Idempotent: safe to run repeatedly. Demo jobs use fixed UUIDs and are deleted
(cascading their applications) before re-insert; extra applicant workers are
upserted; the two real demo accounts are created via the same path the auth
dev-bypass uses, so logging in afterwards reuses them.

Run from the backend directory with the project .env present:

    python -m scripts.seed_demo
"""

from datetime import date, timedelta

from app.config import settings
from app.supabase_client import get_supabase
from app.services.auth_service import _ensure_dev_user

# Fixed UUIDs so re-runs replace the same rows instead of piling up.
XW = {
    "xw1": "dddddddd-0001-0000-0000-000000000000",
    "xw2": "dddddddd-0002-0000-0000-000000000000",
    "xw3": "dddddddd-0003-0000-0000-000000000000",
}
DJ = {
    "dj1": "cccccccc-0001-0000-0000-000000000000",
    "dj2": "cccccccc-0002-0000-0000-000000000000",
    "dj3": "cccccccc-0003-0000-0000-000000000000",
    "dj4": "cccccccc-0004-0000-0000-000000000000",
}


def _d(offset_days: int) -> str:
    return (date.today() + timedelta(days=offset_days)).isoformat()


def main() -> None:
    if settings.APP_ENV == "production":
        raise SystemExit("Refusing to seed demo data in production.")
    if not settings.DEV_WORKER_PHONE or not settings.DEV_EMPLOYER_PHONE:
        raise SystemExit("Set DEV_WORKER_PHONE and DEV_EMPLOYER_PHONE in .env first.")
    if not settings.SUPABASE_JWT_SECRET:
        # _ensure_dev_user itself does not need the secret, but login later does;
        # warn early so the demo isn't half-set-up.
        print("WARNING: SUPABASE_JWT_SECRET is empty — dev OTP login will fail.")

    db = get_supabase()

    # --- 1. Real demo accounts (auth user + users row + profile) --------------
    employer_id = _ensure_dev_user(settings.DEV_EMPLOYER_PHONE, "employer")
    worker_id = _ensure_dev_user(settings.DEV_WORKER_PHONE, "worker")

    # Friendlier display values than the defaults baked into _ensure_dev_user.
    db.table("users").update({"display_name": "Demo Worker"}).eq("id", worker_id).execute()
    db.table("employer_profiles").update(
        {"business_name": "Demo Builders", "business_type": "Construction"}
    ).eq("user_id", employer_id).execute()
    db.table("worker_profiles").update(
        {"skills": ["general labour", "loading", "cleaning"], "rating_avg": 4.5}
    ).eq("user_id", worker_id).execute()

    # --- 2. Extra applicant workers (plain rows, no auth needed) --------------
    extra_workers = [
        (XW["xw1"], "+10000000011", "Ravi Kumar", ["masonry", "painting"], 4.5),
        (XW["xw2"], "+10000000012", "Anita Sharma", ["cleaning", "cooking"], 4.0),
        (XW["xw3"], "+10000000013", "Suresh Patel", ["loading", "driving"], 5.0),
    ]
    db.table("users").upsert(
        [
            {
                "id": wid,
                "phone_number": phone,
                "user_type": "worker",
                "display_name": name,
                "location_lat": 12.97,
                "location_lng": 77.59,
            }
            for wid, phone, name, _skills, _rating in extra_workers
        ],
        on_conflict="id",
    ).execute()
    db.table("worker_profiles").upsert(
        [
            {
                "user_id": wid,
                "skills": skills,
                "availability_status": True,
                "rating_avg": rating,
            }
            for wid, _phone, _name, skills, rating in extra_workers
        ],
        on_conflict="user_id",
    ).execute()

    # --- 3. Categories lookup -------------------------------------------------
    cats = {c["name"]: c["id"] for c in db.table("categories").select("id,name").execute().data}

    def cat(name: str) -> str:
        return cats[name]

    # --- 4. Jobs (delete first to cascade old applications, then insert) ------
    db.table("jobs").delete().in_("id", list(DJ.values())).execute()
    db.table("jobs").insert(
        [
            {
                "id": DJ["dj1"],
                "employer_id": employer_id,
                "category_id": cat("General Labour"),
                "title": "Site Helper - MG Road",
                "description": "General site help: carrying materials, basic clean-up. No experience needed.",
                "location_lat": 12.9756,
                "location_lng": 77.6073,
                "address_text": "MG Road, Bengaluru",
                "wage_per_day": 700,
                "workers_needed": 2,
                "status": "open",
                "start_date": _d(1),
                "end_date": _d(4),
                "is_urgent": False,
            },
            {
                "id": DJ["dj2"],
                "employer_id": employer_id,
                "category_id": cat("Cleaning"),
                "title": "Office Cleaning - Indiranagar",
                "description": "Evening cleaning of a small office. One person needed.",
                "location_lat": 12.9660,
                "location_lng": 77.5980,
                "address_text": "Indiranagar, Bengaluru",
                "wage_per_day": 550,
                "workers_needed": 1,
                "status": "open",
                "start_date": _d(0),
                "end_date": _d(1),
                "is_urgent": True,
            },
            {
                "id": DJ["dj3"],
                "employer_id": employer_id,
                "category_id": cat("Loading & Moving"),
                "title": "Warehouse Loading Shift",
                "description": "Load and unload goods. Heavy lifting involved. Several workers needed.",
                "location_lat": 12.9555,
                "location_lng": 77.6140,
                "address_text": "Peenya, Bengaluru",
                "wage_per_day": 800,
                "workers_needed": 3,
                "status": "open",
                "start_date": _d(2),
                "end_date": _d(3),
                "is_urgent": False,
            },
            {
                "id": DJ["dj4"],
                "employer_id": employer_id,
                "category_id": cat("Painting"),
                "title": "Interior Painting - Whitefield",
                "description": "Two-coat interior painting of an apartment. Already staffed.",
                "location_lat": 12.9698,
                "location_lng": 77.7499,
                "address_text": "Whitefield, Bengaluru",
                "wage_per_day": 850,
                "workers_needed": 2,
                "status": "assigned",
                "start_date": _d(-1),
                "end_date": _d(6),
                "is_urgent": False,
            },
        ]
    ).execute()

    # --- 5. Applications (workers_assigned is set by the DB trigger) ----------
    # dj1: open, needs 2 -> three pending applicants to demo accept/reject.
    # dj2: open, needs 1 -> single pending -> accepting flips it to assigned.
    # dj3: open, needs 3 -> no applicants -> apply live as the worker.
    # dj4: assigned -> demo worker + xw1 accepted (trigger sets assigned=2).
    db.table("applications").insert(
        [
            {"job_id": DJ["dj1"], "worker_id": worker_id, "status": "pending"},
            {"job_id": DJ["dj1"], "worker_id": XW["xw1"], "status": "pending"},
            {"job_id": DJ["dj1"], "worker_id": XW["xw2"], "status": "pending"},
            {"job_id": DJ["dj2"], "worker_id": worker_id, "status": "pending"},
            {"job_id": DJ["dj4"], "worker_id": worker_id, "status": "accepted"},
            {"job_id": DJ["dj4"], "worker_id": XW["xw1"], "status": "accepted"},
        ]
    ).execute()

    print("Demo seed complete.")
    print(f"  Employer {settings.DEV_EMPLOYER_PHONE} -> {employer_id}")
    print(f"  Worker   {settings.DEV_WORKER_PHONE} -> {worker_id}")
    print("  Jobs: 4 (dj1 open+3 applicants, dj2 open+1, dj3 open empty, dj4 assigned)")
    print(f"  Login OTP: {settings.DEV_BYPASS_OTP}")


if __name__ == "__main__":
    main()
