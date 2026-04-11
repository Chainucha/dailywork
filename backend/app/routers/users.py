from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user
from app.schemas.users import UserResponse, UserUpdate
from app.supabase_client import get_supabase

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_me(
    body: UserUpdate,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        return current_user
    result = db.table("users").update(updates).eq("id", current_user["id"]).execute()
    return result.data[0]


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("users").select("*").eq("id", user_id).eq("is_active", True).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")
    return result.data[0]


@router.get("/{user_id}/reviews")
async def get_user_reviews(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = (
        db.table("reviews")
        .select("*, reviewer:reviewer_id(id, phone_number, user_type)")
        .eq("reviewee_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    return {"data": result.data}
