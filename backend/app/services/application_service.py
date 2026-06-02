from datetime import date

from supabase import Client

ACTIVE_CAP = 2  # max concurrent 'accepted' applications per worker


# Job statuses that still represent a live commitment for the worker. A
# completed/cancelled job is done and must not count toward the active cap.
_ACTIVE_JOB_STATUSES = {"open", "assigned", "in_progress"}


def count_active(db: Client, worker_id: str) -> int:
    """Counts the worker's accepted applications on still-active jobs (the cap
    basis). Excludes accepted apps whose job is completed or cancelled."""
    res = (
        db.table("applications")
        .select("id, jobs!inner(status)")
        .eq("worker_id", worker_id)
        .eq("status", "accepted")
        .execute()
    )
    return sum(
        1
        for r in (res.data or [])
        if (r.get("jobs") or {}).get("status") in _ACTIVE_JOB_STATUSES
    )


def enforce_active_cap(db: Client, worker_id: str) -> None:
    """Raises ValueError('at_cap') if the worker already holds ACTIVE_CAP accepted apps."""
    if count_active(db, worker_id) >= ACTIVE_CAP:
        raise ValueError("at_cap")


def _job(db: Client, job_id: str) -> dict:
    res = db.table("jobs").select("*").eq("id", job_id).execute()
    if not res.data:
        raise ValueError("job_not_found")
    return res.data[0]


def accept_application(db: Client, application_id: str, employer_id: str) -> dict:
    """Accepts a pending application: bumps workers_assigned, may flip job open->assigned.

    Raises ValueError codes: not_found, forbidden, bad_status, at_capacity.
    """
    app_res = db.table("applications").select("*").eq("id", application_id).execute()
    if not app_res.data:
        raise ValueError("not_found")
    application = app_res.data[0]
    job = _job(db, application["job_id"])

    if job["employer_id"] != employer_id:
        raise ValueError("forbidden")
    if application["status"] != "pending":
        raise ValueError("bad_status")
    if job["workers_assigned"] >= job["workers_needed"]:
        raise ValueError("at_capacity")

    db.table("applications").update({"status": "accepted"}).eq("id", application_id).execute()

    new_assigned = job["workers_assigned"] + 1
    job_update = {"workers_assigned": new_assigned}
    if new_assigned >= job["workers_needed"] and job["status"] == "open":
        job_update["status"] = "assigned"
    db.table("jobs").update(job_update).eq("id", job["id"]).execute()

    return db.table("applications").select("*").eq("id", application_id).execute().data[0]


def reject_application(db: Client, application_id: str, employer_id: str) -> dict:
    """Rejects a pending application. No assigned-count change. Codes: not_found, forbidden, bad_status."""
    app_res = db.table("applications").select("*").eq("id", application_id).execute()
    if not app_res.data:
        raise ValueError("not_found")
    application = app_res.data[0]
    job = _job(db, application["job_id"])

    if job["employer_id"] != employer_id:
        raise ValueError("forbidden")
    if application["status"] != "pending":
        raise ValueError("bad_status")

    db.table("applications").update({"status": "rejected"}).eq("id", application_id).execute()
    return db.table("applications").select("*").eq("id", application_id).execute().data[0]


def withdraw_application(db: Client, application_id: str, worker_id: str, reason: str | None) -> dict:
    """Worker withdraws own pending/accepted app. If it was accepted, decrement
    workers_assigned and revert job assigned->open when below capacity.
    Codes: not_found, forbidden, bad_status.
    """
    app_res = db.table("applications").select("*").eq("id", application_id).execute()
    if not app_res.data:
        raise ValueError("not_found")
    application = app_res.data[0]
    if application["worker_id"] != worker_id:
        raise ValueError("forbidden")
    if application["status"] not in ("pending", "accepted"):
        raise ValueError("bad_status")

    # Cancellation window: workers may withdraw only before the job's start
    # date. On or after start_date the job is starting/started — too late.
    job = _job(db, application["job_id"])
    start = job["start_date"]
    start_date = date.fromisoformat(start) if isinstance(start, str) else start
    if date.today() >= start_date:
        raise ValueError("too_late")

    was_accepted = application["status"] == "accepted"
    update = {"status": "withdrawn"}
    if reason is not None:
        update["withdrawn_reason"] = reason
    db.table("applications").update(update).eq("id", application_id).execute()

    if was_accepted:
        new_assigned = max(0, job["workers_assigned"] - 1)
        job_update = {"workers_assigned": new_assigned}
        if new_assigned < job["workers_needed"] and job["status"] == "assigned":
            job_update["status"] = "open"
        db.table("jobs").update(job_update).eq("id", job["id"]).execute()

    return db.table("applications").select("*").eq("id", application_id).execute().data[0]


def enrich_applicants(db: Client, rows: list[dict]) -> list[dict]:
    """Maps raw application rows to applicant DTO dicts with worker name/phone/rating.

    Batch-fetches users + worker_profiles to avoid N+1.
    """
    if not rows:
        return []
    worker_ids = list({r["worker_id"] for r in rows})

    users = (
        db.table("users")
        .select("id, display_name, phone_number")
        .in_("id", worker_ids)
        .execute()
    )
    user_map = {u["id"]: u for u in (users.data or [])}

    profiles = (
        db.table("worker_profiles")
        .select("user_id, rating_avg")
        .in_("user_id", worker_ids)
        .execute()
    )
    rating_map = {p["user_id"]: p.get("rating_avg") for p in (profiles.data or [])}

    out = []
    for r in rows:
        u = user_map.get(r["worker_id"], {})
        out.append({
            "application_id": r["id"],
            "worker_id": r["worker_id"],
            "status": r["status"],
            "created_at": r["created_at"],
            "display_name": u.get("display_name") or u.get("phone_number"),
            "phone_number": u.get("phone_number"),
            "rating_avg": rating_map.get(r["worker_id"]),
        })
    return out