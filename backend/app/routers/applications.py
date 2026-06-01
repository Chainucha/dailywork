from fastapi import APIRouter, Depends, HTTPException, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.dependencies import get_current_user, require_worker, require_employer
from app.schemas.applications import (
    ApplicationResponse,
    ApplicationStatusUpdate,
    ApplicantListResponse,
)
from app.services import application_service
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

    try:
        application_service.enforce_active_cap(db, worker["id"])
    except ValueError:
        raise HTTPException(
            status_code=409,
            detail="You're at your active-job limit. Finish a current job first.",
        )

    result = db.table("applications").insert({
        "job_id": job_id,
        "worker_id": worker["id"],
        "status": "pending",
    }).execute()

    # Notify employer (best-effort).
    try:
        from app.services.notification_service import dispatch_notification
        employer = db.table("jobs").select("employer_id").eq("id", job_id).execute().data[0]
        dispatch_notification(
            user_id=employer["employer_id"],
            notif_type="application_received",
            data={"job_id": str(job_id), "application_id": str(result.data[0]["id"])},
        )
    except Exception:
        pass

    return result.data[0]


@router.get("/jobs/{job_id}/applications", response_model=ApplicantListResponse)
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

    rows = (
        db.table("applications")
        .select("*")
        .eq("job_id", job_id)
        .order("created_at", desc=False)
        .execute()
        .data
        or []
    )
    return {"data": application_service.enrich_applicants(db, rows)}


@router.patch("/applications/{application_id}", response_model=ApplicationResponse)
@limiter.limit("30/minute")
async def update_application_status(
    request: Request,
    application_id: str,
    body: ApplicationStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    new_status = body.status

    try:
        if new_status == "accepted":
            if current_user["user_type"] != "employer":
                raise HTTPException(status_code=403, detail="Only employers can accept")
            updated = application_service.accept_application(db, application_id, current_user["id"])
        elif new_status == "rejected":
            if current_user["user_type"] != "employer":
                raise HTTPException(status_code=403, detail="Only employers can reject")
            updated = application_service.reject_application(db, application_id, current_user["id"])
        elif new_status == "withdrawn":
            if current_user["user_type"] == "employer":
                raise HTTPException(status_code=403, detail="Employers cannot withdraw applications")
            updated = application_service.withdraw_application(
                db, application_id, current_user["id"], body.reason
            )
        else:  # pragma: no cover — Literal blocks other values
            raise HTTPException(status_code=400, detail="Unsupported status")
    except ValueError as e:
        code = str(e)
        if code in ("not_found", "job_not_found"):
            raise HTTPException(status_code=404, detail="Application not found")
        if code == "forbidden":
            raise HTTPException(status_code=403, detail="Not allowed")
        if code == "at_capacity":
            raise HTTPException(status_code=400, detail="Job has reached worker capacity")
        if code == "bad_status":
            raise HTTPException(status_code=400, detail="Invalid status transition")
        raise

    # Notify worker on employer decisions (best-effort).
    try:
        from app.services.notification_service import dispatch_notification
        if new_status in ("accepted", "rejected"):
            dispatch_notification(
                user_id=str(updated["worker_id"]),
                notif_type=f"application_{new_status}",
                data={"job_id": str(updated["job_id"]), "application_id": str(updated["id"])},
            )
    except Exception:
        pass

    return updated
