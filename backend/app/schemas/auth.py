from pydantic import BaseModel
from typing import Literal


class SendOtpRequest(BaseModel):
    phone: str


class VerifyOtpRequest(BaseModel):
    phone: str
    token: str


class SetupProfileRequest(BaseModel):
    user_type: Literal["worker", "employer"]


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
