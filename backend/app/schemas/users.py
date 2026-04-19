from pydantic import BaseModel, UUID4, field_validator
from datetime import datetime
from typing import Literal


class UserResponse(BaseModel):
    id: UUID4
    phone_number: str
    user_type: Literal["worker", "employer"]
    display_name: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    fcm_token: str | None = None

    @field_validator("display_name")
    @classmethod
    def _validate_display_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("display_name cannot be empty or whitespace")
        if len(trimmed) > 60:
            raise ValueError("display_name cannot exceed 60 characters")
        return trimmed
