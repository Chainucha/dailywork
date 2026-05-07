from app.supabase_client import get_supabase


def dispatch_notification(
    user_id: str,
    notif_type: str,
    data: dict,
    fcm_token: str | None = None,
) -> None:
    db = get_supabase()
    try:
        db.table("notifications").insert({
            "user_id": user_id,
            "type": notif_type,
            "is_read": False,
            "data": data,
        }).execute()
    except Exception:
        pass
