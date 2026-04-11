from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user
from app.schemas.notifications import NotificationListResponse, NotificationResponse
from app.supabase_client import get_supabase

router = APIRouter(tags=["notifications"])


@router.get("/", response_model=NotificationListResponse)
async def list_notifications(
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = (
        db.table("notifications")
        .select("*")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
        .limit(50)
        .execute()
    )
    notifications = result.data or []
    unread_count = sum(1 for n in notifications if not n["is_read"])
    return {"data": notifications, "unread_count": unread_count}


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_as_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = (
        db.table("notifications")
        .select("*")
        .eq("id", notification_id)
        .eq("user_id", current_user["id"])
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Notification not found")

    updated = (
        db.table("notifications")
        .update({"is_read": True})
        .eq("id", notification_id)
        .execute()
    )
    return updated.data[0]


@router.patch("/read-all", response_model=dict)
async def mark_all_read(current_user: dict = Depends(get_current_user)):
    db = get_supabase()
    db.table("notifications").update({"is_read": True}).eq("user_id", current_user["id"]).eq("is_read", False).execute()
    return {"message": "All notifications marked as read"}
