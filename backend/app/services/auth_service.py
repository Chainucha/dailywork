from fastapi import HTTPException, status
from app.supabase_client import get_supabase, get_auth_client


def send_otp(phone: str) -> dict:
    try:
        get_auth_client().auth.sign_in_with_otp({"phone": phone})
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to send OTP: {str(e)}",
        )
    return {"message": "OTP sent"}


def verify_otp(phone: str, token: str) -> dict:
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


def setup_profile(user_id: str, phone: str, user_type: str) -> None:
    db = get_supabase()

    # Guard against duplicate calls (e.g. user taps twice)
    if db.table("users").select("id").eq("id", user_id).execute().data:
        return

    user_row = db.table("users").insert({
        "id": user_id,
        "phone_number": phone,
        "user_type": user_type,
    }).execute()
    user = user_row.data[0]

    if user_type == "worker":
        db.table("worker_profiles").insert({"user_id": user["id"]}).execute()
    else:
        db.table("employer_profiles").insert({
            "user_id": user["id"],
            "business_name": "My Business",
        }).execute()


def refresh_session(refresh_token: str) -> dict:
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
