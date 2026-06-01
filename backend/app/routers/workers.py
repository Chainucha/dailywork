from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user, require_worker
from app.schemas.workers import WorkerProfileResponse, WorkerProfileUpdate
from app.schemas.jobs import WorkerApplicationsGroupedResponse
from app.services.job_service import _enrich_rows_batch
from app.supabase_client import get_supabase

router = APIRouter(tags=["workers"])


def _count_jobs_completed(db, worker_id: str) -> int:
    """Count applications where worker was accepted AND the job is completed."""
    result = (
        db.table("applications")
        .select("id, jobs!inner(status)", count="exact")
        .eq("worker_id", worker_id)
        .eq("status", "accepted")
        .eq("jobs.status", "completed")
        .execute()
    )
    return result.count or 0


@router.get("/me/profile", response_model=WorkerProfileResponse)
async def get_my_profile(current_user: dict = Depends(require_worker)):
    db = get_supabase()
    result = db.table("worker_profiles").select("*").eq("user_id", current_user["id"]).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Worker profile not found")
    profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, current_user["id"])
    return profile


@router.patch("/me/profile", response_model=WorkerProfileResponse)
async def update_my_profile(
    body: WorkerProfileUpdate,
    current_user: dict = Depends(require_worker),
):
    db = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        result = db.table("worker_profiles").select("*").eq("user_id", current_user["id"]).execute()
        profile = result.data[0]
    else:
        result = (
            db.table("worker_profiles")
            .update(updates)
            .eq("user_id", current_user["id"])
            .execute()
        )
        profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, current_user["id"])
    return profile


@router.get("/me/applications", response_model=WorkerApplicationsGroupedResponse)
async def get_my_applications(current_user: dict = Depends(require_worker)):
    db = get_supabase()

    apps = (
        db.table("applications")
        .select("id, job_id, status, created_at")
        .eq("worker_id", current_user["id"])
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )
    if not apps:
        return {"pending": [], "accepted": [], "rejected": [], "withdrawn": []}

    job_ids = [a["job_id"] for a in apps]
    job_rows = (
        db.table("jobs")
        .select("*, categories(name)")
        .in_("id", job_ids)
        .execute()
        .data
        or []
    )
    enriched = {r["id"]: r for r in _enrich_rows_batch(db, job_rows)}

    grouped = {"pending": [], "accepted": [], "rejected": [], "withdrawn": []}
    for a in apps:
        job = enriched.get(a["job_id"])
        if job is None:  # job deleted — skip orphaned application
            continue
        bucket = grouped.get(a["status"])
        if bucket is None:
            continue
        row = dict(job)
        row["application_id"] = a["id"]
        row["application_status"] = a["status"]
        bucket.append(row)
    return grouped


@router.get("/{user_id}/profile", response_model=WorkerProfileResponse)
async def get_worker_profile(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("worker_profiles").select("*").eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Worker profile not found")
    profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, user_id)
    return profile
