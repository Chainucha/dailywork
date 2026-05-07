from fastapi import APIRouter, Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.dependencies import get_current_user, require_worker, require_employer
from app.schemas.applications import ApplicationResponse, ApplicationStatusUpdate
from app.supabase_client import get_supabase

router = APIRouter(tags=["applications"])
limiter = Limiter(key_func=get_remote_address)


@router.post("/jobs/{job_id}/apply", response_model=ApplicationResponse, status_code=201)
@limiter.limit("20/minute")
async def apply_for_job(
    request: Request,
    job_id: str,
    worker: dict = Depends(require_worker),
):
    db = get_supabase()

    job_result = db.table("jobs").select("status").eq("id", job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    if job_result.data[0]["status"] != "open":
        raise HTTPException(status_code=400, detail="Job is not accepting applications")

    existing = (
        db.table("applications")
        .select("id")
        .eq("job_id", job_id)
        .eq("worker_id", worker["id"])
        .execute()
    )
    if existing.data:
        raise HTTPException(status_code=409, detail="Already applied for this job")

    result = db.table("applications").insert({
        "job_id": job_id,
        "worker_id": worker["id"],
        "status": "pending",
    }).execute()
    return result.data[0]


@router.get("/jobs/{job_id}/applications")
async def list_job_applications(
    job_id: str,
    employer: dict = Depends(require_employer),
):
    db = get_supabase()

    job_result = db.table("jobs").select("employer_id").eq("id", job_id).execute()
    if not job_result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    if job_result.data[0]["employer_id"] != employer["id"]:
        raise HTTPException(status_code=403, detail="Not your job")

    result = (
        db.table("applications")
        .select("*, worker:worker_id(id, phone_number, user_type)")
        .eq("job_id", job_id)
        .order("created_at", desc=False)
        .execute()
    )
    return {"data": result.data}


@router.patch("/applications/{application_id}", response_model=ApplicationResponse)
@limiter.limit("30/minute")
async def update_application_status(
    request: Request,
    application_id: str,
    body: ApplicationStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()

    app_result = (
        db.table("applications")
        .select("*, job:job_id(employer_id, workers_assigned, workers_needed, start_date)")
        .eq("id", application_id)
        .execute()
    )
    if not app_result.data:
        raise HTTPException(status_code=404, detail="Application not found")

    application = app_result.data[0]
    job = application["job"]
    new_status = body.status

    if new_status in ("accepted", "rejected"):
        if current_user["user_type"] != "employer":
            raise HTTPException(status_code=403, detail="Only employers can accept/reject")
        if job["employer_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not your job")
        if application["status"] != "pending":
            raise HTTPException(status_code=400, detail="Can only accept/reject pending applications")
        if new_status == "accepted" and job["workers_assigned"] >= job["workers_needed"]:
            raise HTTPException(status_code=400, detail="Job has reached worker capacity")

    elif new_status == "withdrawn":
        if current_user["user_type"] == "employer":
            raise HTTPException(status_code=403, detail="Employers cannot withdraw applications")
        if application["worker_id"] != current_user["id"]:
            raise HTTPException(status_code=403, detail="Not your application")
        if application["status"] not in ("pending", "accepted"):
            raise HTTPException(status_code=400, detail="Cannot withdraw in current status")

    result = (
        db.table("applications")
        .update({"status": new_status})
        .eq("id", application_id)
        .execute()
    )

    # Write notification record (best-effort)
    try:
        from app.services.notification_service import dispatch_notification
        if new_status in ("accepted", "rejected"):
            dispatch_notification(
                user_id=application["worker_id"],
                notif_type=f"application_{new_status}",
                data={"job_id": str(application["job_id"]), "application_id": str(application["id"])},
            )
    except Exception:
        pass

    return result.data[0]
