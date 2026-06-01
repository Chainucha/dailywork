from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class NotificationResponse(BaseModel):
    id: UUID
    user_id: UUID
    type: str
    is_read: bool
    data: dict
    created_at: datetime


class NotificationListResponse(BaseModel):
    data: list[NotificationResponse]
    unread_count: int
