import time

import jwt as pyjwt
from fastapi import HTTPException, status

from app.config import settings
from app.supabase_client import get_supabase, get_auth_client


# ---------------------------------------------------------------------------
# Dev bypass helpers (non-production only)
# ---------------------------------------------------------------------------

def _dev_user_type(phone: str) -> str | None:
    """Return 'worker'/'employer' if phone matches a dev bypass number, else None.
    Always returns None in production regardless of env vars.
    """
    if settings.APP_ENV == "production":
        return None
    if settings.DEV_WORKER_PHONE and phone == settings.DEV_WORKER_PHONE:
        return "worker"
    if settings.DEV_EMPLOYER_PHONE and phone == settings.DEV_EMPLOYER_PHONE:
        return "employer"
    return None


def _ensure_dev_user(phone: str, user_type: str) -> str:
    """Idempotent: get-or-create Supabase auth user + app user row. Returns UUID."""
    db = get_supabase()

    # Fast path — user already fully set up.
    existing = db.table("users").select("id").eq("phone_number", phone).execute()
    if existing.data:
        return existing.data[0]["id"]

    # Create in Supabase Auth (service role client has admin access).
    result = db.auth.admin.create_user({"phone": phone, "phone_confirm": True})
    user_id = result.user.id

    db.table("users").insert({
        "id": user_id,
        "phone_number": phone,
        "user_type": user_type,
        "display_name": f"Dev {user_type.capitalize()}",
    }).execute()

    if user_type == "worker":
        db.table("worker_profiles").insert({"user_id": user_id}).execute()
    else:
        db.table("employer_profiles").insert({
            "user_id": user_id,
            "business_name": "Dev Business",
        }).execute()

    return user_id


def _mint_dev_tokens(user_id: str, phone: str) -> tuple[str, str]:
    """Mint HS256 access token (24 h) + opaque dev refresh token."""
    now = int(time.time())
    access_token = pyjwt.encode(
        {
            "sub": user_id,
            "phone": phone,
            "iat": now,
            "exp": now + 86400,
            "role": "authenticated",
            "iss": "supabase",
            "aud": "authenticated",
        },
        settings.SUPABASE_JWT_SECRET,
        algorithm="HS256",
    )
    return access_token, f"dev_{user_id}"


# ---------------------------------------------------------------------------
# Public service functions
# ---------------------------------------------------------------------------

def send_otp(phone: str) -> dict:
    if _dev_user_type(phone) is not None:
        return {"message": "OTP sent"}

    try:
        get_auth_client().auth.sign_in_with_otp({"phone": phone})
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to send OTP: {str(e)}",
        )
    return {"message": "OTP sent"}


def verify_otp(phone: str, token: str) -> dict:
    user_type = _dev_user_type(phone)
    if user_type is not None:
        if token != settings.DEV_BYPASS_OTP:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid OTP",
            )
        if not settings.SUPABASE_JWT_SECRET:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="SUPABASE_JWT_SECRET required for dev bypass",
            )
        user_id = _ensure_dev_user(phone, user_type)
        access_token, refresh_token = _mint_dev_tokens(user_id, phone)
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "user_id": user_id,
            "user_type": user_type,
            "is_new_user": False,
        }

    # Use a fresh auth client — verify_otp sets the user session internally,
    # which would overwrite the service role key on a shared client.
    try:
        result = get_auth_client().auth.verify_otp(
            {"phone": phone, "token": token, "type": "sms"}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid OTP: {str(e)}",
        )

    auth_user = result.user
    session = result.session

    db = get_supabase()
    existing = db.table("users").select("*").eq("id", auth_user.id).execute()

    if existing.data:
        user = existing.data[0]
        return {
            "access_token": session.access_token,
            "refresh_token": session.refresh_token,
            "token_type": "bearer",
            "user_id": user["id"],
            "user_type": user["user_type"],
            "is_new_user": False,
        }

    # New user — return tokens so the client can call /auth/setup-profile next.
    return {
        "access_token": session.access_token,
        "refresh_token": session.refresh_token,
        "token_type": "bearer",
        "user_id": auth_user.id,
        "user_type": None,
        "is_new_user": True,
    }


def setup_profile(
    user_id: str,
    phone: str,
    user_type: str,
    display_name: str | None = None,
) -> None:
    db = get_supabase()

    # Guard against duplicate calls (e.g. user taps twice)
    if db.table("users").select("id").eq("id", user_id).execute().data:
        return

    user_payload = {
        "id": user_id,
        "phone_number": phone,
        "user_type": user_type,
    }
    if display_name is not None:
        user_payload["display_name"] = display_name

    user_row = db.table("users").insert(user_payload).execute()
    user = user_row.data[0]

    if user_type == "worker":
        db.table("worker_profiles").insert({"user_id": user["id"]}).execute()
    else:
        db.table("employer_profiles").insert({
            "user_id": user["id"],
            "business_name": "My Business",
        }).execute()


def refresh_session(refresh_token: str) -> dict:
    # Dev refresh token bypass.
    if refresh_token.startswith("dev_") and settings.APP_ENV != "production":
        user_id = refresh_token.removeprefix("dev_")
        db = get_supabase()
        result = db.table("users").select("phone_number").eq("id", user_id).execute()
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
            )
        phone = result.data[0]["phone_number"]
        access_token, new_refresh = _mint_dev_tokens(user_id, phone)
        return {
            "access_token": access_token,
            "refresh_token": new_refresh,
            "token_type": "bearer",
            "user_id": user_id,
            "user_type": "",
        }

    try:
        result = get_auth_client().auth.refresh_session(refresh_token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid refresh token: {str(e)}",
        )
    return {
        "access_token": result.session.access_token,
        "refresh_token": result.session.refresh_token,
        "token_type": "bearer",
        "user_id": result.user.id,
        "user_type": "",  # caller fetches from users table if needed
    }


def logout(user_id: str) -> None:
    try:
        get_auth_client().auth.sign_out()
    except Exception:
        pass  # best-effort logout
