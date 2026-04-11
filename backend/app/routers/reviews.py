from fastapi import APIRouter, Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.dependencies import get_current_user
from app.schemas.reviews import ReviewCreate, ReviewResponse
from app.supabase_client import get_supabase

router = APIRouter(tags=["reviews"])
limiter = Limiter(key_func=get_remote_address)


@router.post("/", response_model=ReviewResponse, status_code=201)
@limiter.limit("20/minute")
async def create_review(
    request: Request,
    body: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    job_id = str(body.job_id)
    reviewee_id = str(body.reviewee_id)

    # Job must be completed
    job_result = db.table("jobs").select("status, employer_id").eq("id", job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    job = job_result.data[0]
    if job["status"] != "completed":
        raise HTTPException(status_code=400, detail="Reviews only allowed on completed jobs")

    # Verify reviewer participated in the job
    if current_user["user_type"] == "worker":
        participation = (
            db.table("applications")
            .select("id")
            .eq("job_id", job_id)
            .eq("worker_id", current_user["id"])
            .eq("status", "accepted")
            .execute()
        )
        if not participation.data:
            raise HTTPException(status_code=403, detail="You did not work on this job")
    elif current_user["user_type"] == "employer":
        if job["employer_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not your job")

    # Duplicate check (also enforced by DB unique constraint)
    existing = (
        db.table("reviews")
        .select("id")
        .eq("reviewer_id", current_user["id"])
        .eq("job_id", job_id)
        .execute()
    )
    if existing.data:
        raise HTTPException(status_code=409, detail="Already reviewed this job")

    result = db.table("reviews").insert({
        "reviewer_id": current_user["id"],
        "reviewee_id": reviewee_id,
        "job_id": job_id,
        "rating": body.rating,
        "comment": body.comment,
    }).execute()
    return result.data[0]
