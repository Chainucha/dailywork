from pydantic import BaseModel, UUID4
from datetime import datetime


class NotificationResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    type: str
    is_read: bool
    data: dict
    created_at: datetime


class NotificationListResponse(BaseModel):
    data: list[NotificationResponse]
    unread_count: int
