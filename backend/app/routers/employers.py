from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user, require_employer
from app.schemas.employers import EmployerProfileResponse, EmployerProfileUpdate
from app.supabase_client import get_supabase

router = APIRouter(tags=["employers"])


def _count_jobs_posted(db, employer_id: str) -> int:
    result = (
        db.table("jobs")
        .select("id", count="exact")
        .eq("employer_id", employer_id)
        .execute()
    )
    return result.count or 0


@router.get("/me/profile", response_model=EmployerProfileResponse)
async def get_my_profile(current_user: dict = Depends(require_employer)):
    db = get_supabase()
    result = db.table("employer_profiles").select("*").eq("user_id", current_user["id"]).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, current_user["id"])
    return profile


@router.patch("/me/profile", response_model=EmployerProfileResponse)
async def update_my_profile(
    body: EmployerProfileUpdate,
    current_user: dict = Depends(require_employer),
):
    db = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        result = db.table("employer_profiles").select("*").eq("user_id", current_user["id"]).execute()
        profile = result.data[0]
    else:
        result = (
            db.table("employer_profiles")
            .update(updates)
            .eq("user_id", current_user["id"])
            .execute()
        )
        profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, current_user["id"])
    return profile


@router.get("/{user_id}/profile", response_model=EmployerProfileResponse)
async def get_employer_profile(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("employer_profiles").select("*").eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, user_id)
    return profile
