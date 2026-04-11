from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from app.config import settings
from app.supabase_client import get_supabase

bearer = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
):
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    db = get_supabase()
    result = db.table("users").select("*").eq("id", user_id).eq("is_active", True).execute()
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return result.data[0]


async def require_worker(current_user: dict = Depends(get_current_user)):
    if current_user["user_type"] != "worker":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Workers only",
        )
    return current_user


async def require_employer(current_user: dict = Depends(get_current_user)):
    if current_user["user_type"] != "employer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Employers only",
        )
    return current_user
