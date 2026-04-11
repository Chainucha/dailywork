from app.tasks.notification_tasks import send_push_notification


def dispatch_notification(
    user_id: str,
    notif_type: str,
    data: dict,
    fcm_token: str | None = None,
) -> None:
    send_push_notification.delay(user_id, notif_type, data, fcm_token)
