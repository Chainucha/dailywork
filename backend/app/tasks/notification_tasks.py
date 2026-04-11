import httpx
from app.celery_app import celery
from app.supabase_client import get_supabase
from app.config import settings


@celery.task(bind=True, max_retries=3, default_retry_delay=30)
def send_push_notification(
    self,
    user_id: str,
    notif_type: str,
    data: dict,
    fcm_token: str | None,
):
    db = get_supabase()

    # 1. Write to notifications table
    try:
        db.table("notifications").insert({
            "user_id": user_id,
            "type": notif_type,
            "is_read": False,
            "data": data,
        }).execute()
    except Exception as exc:
        raise self.retry(exc=exc)

    # 2. Send FCM push if token available
    if fcm_token and settings.FCM_SERVER_KEY:
        try:
            _send_fcm(fcm_token, notif_type, data)
        except Exception as exc:
            raise self.retry(exc=exc)


def _send_fcm(token: str, title: str, data: dict) -> None:
    headers = {
        "Authorization": f"key={settings.FCM_SERVER_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "to": token,
        "notification": {
            "title": title,
            "body": data.get("message", ""),
        },
        "data": data,
    }
    response = httpx.post(
        "https://fcm.googleapis.com/fcm/send",
        json=payload,
        headers=headers,
        timeout=10,
    )
    response.raise_for_status()
