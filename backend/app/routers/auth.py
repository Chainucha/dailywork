from fastapi import APIRouter, Depends, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.schemas.auth import (
    SendOtpRequest, VerifyOtpRequest, SetupProfileRequest,
    RefreshRequest, TokenResponse, MessageResponse,
)
from app.services import auth_service
from app.dependencies import get_current_user, get_jwt_payload

router = APIRouter(tags=["auth"])
limiter = Limiter(key_func=get_remote_address)


@router.post("/send-otp", response_model=MessageResponse)
@limiter.limit("10/minute")
async def send_otp(request: Request, body: SendOtpRequest):
    return auth_service.send_otp(body.phone)


@router.post("/verify-otp", response_model=TokenResponse)
@limiter.limit("10/minute")
async def verify_otp(request: Request, body: VerifyOtpRequest):
    return auth_service.verify_otp(body.phone, body.token)


@router.post("/setup-profile", response_model=MessageResponse)
async def setup_profile(
    body: SetupProfileRequest,
    jwt: dict = Depends(get_jwt_payload),
):
    auth_service.setup_profile(
        jwt["sub"],
        jwt["phone"],
        body.user_type,
        display_name=body.display_name,
    )
    return {"message": "Profile created"}


@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest):
    return auth_service.refresh_session(body.refresh_token)


@router.post("/logout", response_model=MessageResponse)
async def logout(current_user: dict = Depends(get_current_user)):
    auth_service.logout(current_user["id"])
    return {"message": "Logged out"}
