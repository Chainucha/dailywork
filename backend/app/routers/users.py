from fastapi import APIRouter, Depends, HTTPException, Query
from app.dependencies import get_current_user
from app.schemas.users import UserResponse, UserUpdate
from app.schemas.reviews import ReviewListResponse
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


@router.get("/{user_id}/reviews", response_model=ReviewListResponse)
async def get_user_reviews(
    user_id: str,
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()

    page = (
        db.table("reviews")
        .select("id, rating, comment, created_at, reviewer:reviewer_id(display_name, phone_number)")
        .eq("reviewee_id", user_id)
        .order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    total_result = (
        db.table("reviews")
        .select("id", count="exact")
        .eq("reviewee_id", user_id)
        .execute()
    )

    items = []
    for r in page.data:
        reviewer = r.get("reviewer") or {}
        items.append({
            "id": r["id"],
            "rating": r["rating"],
            "comment": r["comment"],
            "created_at": r["created_at"],
            "reviewer_display_name": reviewer.get("display_name") or reviewer.get("phone_number") or "",
        })

    return {
        "items": items,
        "total": total_result.count or 0,
        "limit": limit,
        "offset": offset,
    }
