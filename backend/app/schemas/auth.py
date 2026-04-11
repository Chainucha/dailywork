from pydantic import BaseModel
from typing import Literal


class SendOtpRequest(BaseModel):
    phone: str
    user_type: Literal["worker", "employer"] | None = None  # required on first sign-up


class VerifyOtpRequest(BaseModel):
    phone: str
    token: str
    user_type: Literal["worker", "employer"] | None = None  # required for new users


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    user_type: str


class MessageResponse(BaseModel):
    message: str
