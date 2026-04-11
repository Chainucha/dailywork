from pydantic import BaseModel, UUID4
from datetime import datetime
from typing import Literal


class UserResponse(BaseModel):
    id: UUID4
    phone_number: str
    user_type: Literal["worker", "employer"]
    location_lat: float | None = None
    location_lng: float | None = None
    created_at: datetime


class UserUpdate(BaseModel):
    location_lat: float | None = None
    location_lng: float | None = None
    fcm_token: str | None = None
