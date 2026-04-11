from fastapi import APIRouter, Depends, HTTPException, Query, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.dependencies import get_current_user, require_employer
from app.schemas.jobs import JobCreate, JobUpdate, JobResponse, JobListResponse
from app.services import job_service
from app.supabase_client import get_supabase

router = APIRouter(tags=["jobs"])
limiter = Limiter(key_func=get_remote_address)

VALID_STATUS_TRANSITIONS = {
    "open": {"assigned", "cancelled"},
    "assigned": {"in_progress", "cancelled"},
    "in_progress": {"completed"},
    "completed": set(),
    "cancelled": set(),
}


@router.get("/", response_model=JobListResponse)
async def list_jobs(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float = Query(25.0, gt=0, le=200),
    category_id: str | None = Query(None),
    status: str = Query("open"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    return await job_service.get_jobs_feed(
        db, lat, lng, radius_km, category_id, status, page, page_size
    )


@router.post("/", response_model=JobResponse, status_code=201)
@limiter.limit("30/minute")
async def create_job(
    request: Request,
    body: JobCreate,
    employer: dict = Depends(require_employer),
):
    db = get_supabase()
    payload = body.model_dump()
    payload["employer_id"] = employer["id"]
    payload["status"] = "open"
    payload["workers_assigned"] = 0
    # Convert UUID fields to str for supabase-py
    payload["category_id"] = str(payload["category_id"])

    result = db.table("jobs").insert(payload).execute()
    await job_service.invalidate_job_cache()
    return result.data[0]


@router.get("/{job_id}", response_model=JobResponse)
async def get_job(
    job_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("jobs").select("*").eq("id", job_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    return result.data[0]


@router.patch("/{job_id}", response_model=JobResponse)
@limiter.limit("30/minute")
async def update_job(
    request: Request,
    job_id: str,
    body: JobUpdate,
    employer: dict = Depends(require_employer),
):
    db = get_supabase()
    job_result = db.table("jobs").select("*").eq("id", job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Job not found")

    job = job_result.data[0]
    if job["employer_id"] != employer["id"]:
        raise HTTPException(status_code=403, detail="Not your job")

    updates = body.model_dump(exclude_none=True)
    if not updates:
        return job

    # Validate status transition
    if "status" in updates:
        new_status = updates["status"]
        allowed = VALID_STATUS_TRANSITIONS.get(job["status"], set())
        if new_status not in allowed:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot transition from '{job['status']}' to '{new_status}'",
            )

    result = db.table("jobs").update(updates).eq("id", job_id).execute()
    await job_service.invalidate_job_cache()
    return result.data[0]


@router.delete("/{job_id}", status_code=204)
@limiter.limit("10/minute")
async def delete_job(
    request: Request,
    job_id: str,
    employer: dict = Depends(require_employer),
):
    db = get_supabase()
    job_result = db.table("jobs").select("*").eq("id", job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Job not found")

    job = job_result.data[0]
    if job["employer_id"] != employer["id"]:
        raise HTTPException(status_code=403, detail="Not your job")
    if job["status"] != "open":
        raise HTTPException(status_code=400, detail="Only open jobs can be deleted")

    accepted = (
        db.table("applications")
        .select("id")
        .eq("job_id", job_id)
        .eq("status", "accepted")
        .execute()
    )
    if accepted.data:
        raise HTTPException(status_code=400, detail="Cannot delete job with accepted applicants")

    db.table("jobs").delete().eq("id", job_id).execute()
    await job_service.invalidate_job_cache()
