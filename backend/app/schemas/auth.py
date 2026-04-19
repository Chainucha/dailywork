from pydantic import BaseModel, field_validator
from typing import Literal


class SendOtpRequest(BaseModel):
    phone: str


class VerifyOtpRequest(BaseModel):
    phone: str
    token: str


class SetupProfileRequest(BaseModel):
    user_type: Literal["worker", "employer"]
    display_name: str | None = None

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


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    user_type: str | None = None
    is_new_user: bool = False


class MessageResponse(BaseModel):
    message: str
