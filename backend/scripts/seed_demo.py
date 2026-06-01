"""Seed focused demo data around the two dev-bypass accounts.

Scope (kept deliberately small for a clean demo):
  * Only the two real demo accounts exist as users — no extra applicant rows.
  * All jobs are in the Agriculture category, centred on Mangalore.
  * Employer (DEV_EMPLOYER_PHONE) gets 1-2 jobs in every status section:
    open, assigned, in_progress, completed, cancelled.
  * Worker (DEV_WORKER_PHONE) only carries completed ("done") jobs, with
    bidirectional reviews so ratings and jobs_completed populate.

Jobs with no applicants (open/assigned/in_progress/cancelled) get their
workers_assigned set directly — the sync trigger only fires on application
events, so those values persist. Completed jobs receive a real accepted
application from the demo worker, which the trigger counts.

Idempotent: demo jobs use fixed UUIDs and are deleted (cascading their
applications and reviews) before re-insert. The two accounts are reused via
the same path as the auth dev-bypass. Run from the backend directory:

    python -m scripts.seed_demo
"""

from datetime import date, timedelta

from app.config import settings
from app.supabase_client import get_supabase
from app.services.auth_service import _ensure_dev_user

# Demo map centre — Mangalore.
CENTER_LAT = 12.871384
CENTER_LNG = 74.842644

# Fixed job UUIDs so re-runs replace the same rows.
DJ = {
    "open1": "cccccccc-0001-0000-0000-000000000000",
    "open2": "cccccccc-0002-0000-0000-000000000000",
    "assigned": "cccccccc-0003-0000-0000-000000000000",
    "inprogress": "cccccccc-0004-0000-0000-000000000000",
    "done1": "cccccccc-0005-0000-0000-000000000000",
    "done2": "cccccccc-0006-0000-0000-000000000000",
    "cancelled": "cccccccc-0007-0000-0000-000000000000",
}


def _d(offset_days: int) -> str:
    return (date.today() + timedelta(days=offset_days)).isoformat()


def main() -> None:
    if settings.APP_ENV == "production":
        raise SystemExit("Refusing to seed demo data in production.")
    if not settings.DEV_WORKER_PHONE or not settings.DEV_EMPLOYER_PHONE:
        raise SystemExit("Set DEV_WORKER_PHONE and DEV_EMPLOYER_PHONE in .env first.")

    db = get_supabase()

    # --- 1. Real demo accounts (auth user + users row + profile) --------------
    employer_id = _ensure_dev_user(settings.DEV_EMPLOYER_PHONE, "employer")
    worker_id = _ensure_dev_user(settings.DEV_WORKER_PHONE, "worker")

    db.table("users").update({"display_name": "Demo Worker"}).eq("id", worker_id).execute()
    db.table("employer_profiles").update(
        {"business_name": "Demo Agro Farm", "business_type": "Agriculture"}
    ).eq("user_id", employer_id).execute()
    # rating_avg is left to the reviews trigger (worker has completed jobs below).
    db.table("worker_profiles").update(
        {"skills": ["harvesting", "planting", "irrigation"]}
    ).eq("user_id", worker_id).execute()

    # --- 2. Agriculture category id ------------------------------------------
    cat = db.table("categories").select("id").eq("name", "Agriculture").execute()
    if not cat.data:
        raise SystemExit("Agriculture category missing — run migration 004 seed.")
    agri_id = cat.data[0]["id"]

    def job(jid, title, desc, lat, lng, area, wage, needed, status,
            start_off, end_off, assigned=0, urgent=False, cancel=None):
        row = {
            "id": jid,
            "employer_id": employer_id,
            "category_id": agri_id,
            "title": title,
            "description": desc,
            "location_lat": lat,
            "location_lng": lng,
            "address_text": f"{area}, Mangalore",
            "wage_per_day": wage,
            "workers_needed": needed,
            "workers_assigned": assigned,
            "status": status,
            "start_date": _d(start_off),
            "end_date": _d(end_off),
            "is_urgent": urgent,
        }
        if cancel is not None:
            row["cancellation_reason"] = cancel
        return row

    # --- 3. Jobs (delete first to cascade old applications + reviews) --------
    db.table("jobs").delete().in_("id", list(DJ.values())).execute()
    db.table("jobs").insert([
        # open (shown in worker feed) — no applicants
        job(DJ["open1"], "Paddy Field Harvesting", "Harvest paddy by hand. No experience needed, tools provided.",
            12.8714, 74.8426, "Kankanady", 600, 4, "open", 1, 4),
        job(DJ["open2"], "Coconut Plucking", "Pluck coconuts from a small plantation. Climbing experience preferred.",
            12.8780, 74.8500, "Bejai", 750, 2, "open", 0, 2, urgent=True),
        # assigned — staffed, no live applicants (count set directly)
        job(DJ["assigned"], "Banana Plantation Weeding", "Weeding and clearing around banana plants.",
            12.8650, 74.8350, "Ullal", 550, 2, "assigned", 0, 6, assigned=2),
        # in_progress — currently underway
        job(DJ["inprogress"], "Areca Nut Drying", "Spread and turn areca nuts for drying.",
            12.8800, 74.8550, "Surathkal", 500, 1, "in_progress", -2, 2, assigned=1),
        # completed — these are the worker's "done" jobs
        job(DJ["done1"], "Mango Orchard Harvesting", "Picked and crated mangoes. Completed last week.",
            12.8600, 74.8300, "Deralakatte", 700, 1, "completed", -10, -5),
        job(DJ["done2"], "Vegetable Field Planting", "Planted seedlings across the field. Completed.",
            12.8900, 74.8600, "Mulki", 650, 1, "completed", -7, -6),
        # cancelled
        job(DJ["cancelled"], "Sugarcane Cutting", "Cut and bundle sugarcane.",
            12.8550, 74.8480, "Bantwal", 800, 3, "cancelled", 1, 3,
            cancel="Crop sold to a contractor instead."),
    ]).execute()

    # --- 4. Applications: worker accepted on the two completed jobs only ------
    # (trigger sets workers_assigned = 1 on each.)
    db.table("applications").insert([
        {"job_id": DJ["done1"], "worker_id": worker_id, "status": "accepted"},
        {"job_id": DJ["done2"], "worker_id": worker_id, "status": "accepted"},
    ]).execute()

    # --- 5. Reviews on the completed jobs (trigger recalculates ratings) ------
    db.table("reviews").insert([
        {"reviewer_id": employer_id, "reviewee_id": worker_id,
         "job_id": DJ["done1"], "rating": 5, "comment": "Excellent harvest, very careful."},
        {"reviewer_id": worker_id, "reviewee_id": employer_id,
         "job_id": DJ["done1"], "rating": 5, "comment": "Good pay, clear work."},
        {"reviewer_id": employer_id, "reviewee_id": worker_id,
         "job_id": DJ["done2"], "rating": 4, "comment": "Solid planting work."},
        {"reviewer_id": worker_id, "reviewee_id": employer_id,
         "job_id": DJ["done2"], "rating": 4, "comment": "Fair employer."},
    ]).execute()

    print("Demo seed complete (Mangalore / Agriculture).")
    print(f"  Employer {settings.DEV_EMPLOYER_PHONE} -> {employer_id}  (Demo Agro Farm)")
    print(f"  Worker   {settings.DEV_WORKER_PHONE} -> {worker_id}  (Demo Worker)")
    print("  Employer jobs per section: open x2, assigned x1, in_progress x1,")
    print("                             completed x2, cancelled x1")
    print("  Worker: 2 completed jobs, rating ~4.5 from reviews.")
    print(f"  Centre: {CENTER_LAT}, {CENTER_LNG}   Login OTP: {settings.DEV_BYPASS_OTP}")


if __name__ == "__main__":
    main()
