from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt as pyjwt
from jwt import PyJWKClient
from app.config import settings
from app.supabase_client import get_supabase

bearer = HTTPBearer()

# JWKS client — caches keys automatically, refreshes on key rotation.
_jwks_client: PyJWKClient | None = None


def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(
            settings.SUPABASE_JWKS_URL,
            cache_keys=True,
            lifespan=300,  # re-fetch keys every 5 minutes
        )
    return _jwks_client


def _get_signing_key(token: str):
    """Fetch the matching public key from Supabase JWKS endpoint."""
    return _get_jwks_client().get_signing_key_from_jwt(token)


def _decode_token(token: str) -> dict:
    """JWKS (RS256/ES256/ES384/RS512) first, HS256 fallback, then raise."""
    try:
        signing_key = _get_signing_key(token)
        return pyjwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256", "ES256", "ES384", "RS512"],
            options={"verify_aud": False},
        )
    except Exception:
        pass

    if settings.SUPABASE_JWT_SECRET:
        try:
            return pyjwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
        except Exception:
            pass

    raise pyjwt.InvalidTokenError("Token verification failed")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
):
    token = credentials.credentials
    try:
        payload = _decode_token(token)
    except pyjwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    except Exception:
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


async def get_jwt_payload(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    """Decode JWT without requiring a users table row.
    Used for /auth/setup-profile, called by newly verified users who don't
    have a users row yet. Phone is included in Supabase's phone-auth JWT.
    """
    token = credentials.credentials
    try:
        payload = _decode_token(token)
    except Exception:
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
    return {"sub": user_id, "phone": payload.get("phone", "")}


optional_bearer = HTTPBearer(auto_error=False)


async def optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
) -> dict | None:
    """Like get_current_user but returns None instead of raising 401.

    Used for public endpoints where auth enhances (but isn't required for) the response.
    Intentionally treats both missing tokens AND invalid/expired tokens as anonymous —
    this supports the browse-first UX where expired sessions can still view public content.
    """
    if credentials is None:
        return None
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None


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
