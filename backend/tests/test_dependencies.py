from app.config import Settings


def test_jwks_url_derived_from_supabase_url():
    """JWKS URL should default to {SUPABASE_URL}/auth/v1/.well-known/jwks.json"""
    s = Settings(
        _env_file=None,
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWKS_URL == "https://abc.supabase.co/auth/v1/.well-known/jwks.json"


def test_jwt_secret_is_optional():
    """HS256 fallback secret should default to empty string."""
    s = Settings(
        _env_file=None,
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWT_SECRET == ""


import time
from unittest.mock import patch, MagicMock

import jwt as pyjwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from fastapi import HTTPException
import pytest

from app.dependencies import get_current_user


# ── helpers ──────────────────────────────────────────────────────────

def _generate_rsa_keypair():
    """Generate an RSA private/public key pair for testing."""
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()
    return private_key, public_key


def _make_token(private_key, sub: str = "user-123", exp_offset: int = 300) -> str:
    """Create a signed RS256 JWT."""
    payload = {
        "sub": sub,
        "exp": int(time.time()) + exp_offset,
        "aud": "authenticated",
    }
    pem = private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    return pyjwt.encode(payload, pem, algorithm="RS256")


def _make_hs256_token(secret: str, sub: str = "user-123", exp_offset: int = 300) -> str:
    """Create a signed HS256 JWT."""
    payload = {
        "sub": sub,
        "exp": int(time.time()) + exp_offset,
    }
    return pyjwt.encode(payload, secret, algorithm="HS256")


# ── mock credentials object ─────────────────────────────────────────

class FakeCredentials:
    def __init__(self, token: str):
        self.credentials = token


# ── tests ────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_valid_rs256_token_returns_user():
    private_key, public_key = _generate_rsa_keypair()
    token = _make_token(private_key)

    mock_signing_key = MagicMock()
    mock_signing_key.key = public_key

    fake_user = {"id": "user-123", "user_type": "worker", "is_active": True}

    with (
        patch("app.dependencies._get_signing_key", return_value=mock_signing_key),
        patch("app.dependencies.settings") as mock_settings,
        patch("app.dependencies.get_supabase") as mock_db,
    ):
        mock_settings.SUPABASE_JWT_SECRET = ""
        mock_db.return_value.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [fake_user]

        user = await get_current_user(FakeCredentials(token))
        assert user["id"] == "user-123"


@pytest.mark.asyncio
async def test_expired_token_raises_401():
    private_key, public_key = _generate_rsa_keypair()
    token = _make_token(private_key, exp_offset=-60)  # already expired

    mock_signing_key = MagicMock()
    mock_signing_key.key = public_key

    with (
        patch("app.dependencies._get_signing_key", return_value=mock_signing_key),
        patch("app.dependencies.settings") as mock_settings,
    ):
        mock_settings.SUPABASE_JWT_SECRET = ""
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(FakeCredentials(token))
        assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_hs256_fallback_when_jwks_fails():
    secret = "test-hs256-secret"
    token = _make_hs256_token(secret)

    fake_user = {"id": "user-123", "user_type": "employer", "is_active": True}

    with (
        patch("app.dependencies._get_signing_key", side_effect=Exception("JWKS unavailable")),
        patch("app.dependencies.settings") as mock_settings,
        patch("app.dependencies.get_supabase") as mock_db,
    ):
        mock_settings.SUPABASE_JWT_SECRET = secret
        mock_db.return_value.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [fake_user]

        user = await get_current_user(FakeCredentials(token))
        assert user["id"] == "user-123"


@pytest.mark.asyncio
async def test_expired_rs256_token_raises_401_even_with_hs256_secret():
    """Expiry must be caught on the RS256 path, not via fallback exhaustion.

    With a valid HS256 secret configured, an expired RS256 token must still 401
    immediately — it must NOT fall through to HS256 as if JWKS was unavailable.
    """
    private_key, public_key = _generate_rsa_keypair()
    token = _make_token(private_key, exp_offset=-60)  # already expired

    mock_signing_key = MagicMock()
    mock_signing_key.key = public_key

    with (
        patch("app.dependencies._get_signing_key", return_value=mock_signing_key),
        patch("app.dependencies.settings") as mock_settings,
    ):
        mock_settings.SUPABASE_JWT_SECRET = "a-valid-hs256-secret-long-enough-32ch"
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(FakeCredentials(token))
        assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_no_sub_claim_raises_401():
    private_key, public_key = _generate_rsa_keypair()
    # Token without sub claim
    pem = private_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    token = pyjwt.encode(
        {"exp": int(time.time()) + 300, "aud": "authenticated"},
        pem,
        algorithm="RS256",
    )

    mock_signing_key = MagicMock()
    mock_signing_key.key = public_key

    with (
        patch("app.dependencies._get_signing_key", return_value=mock_signing_key),
        patch("app.dependencies.settings") as mock_settings,
    ):
        mock_settings.SUPABASE_JWT_SECRET = ""
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(FakeCredentials(token))
        assert exc_info.value.status_code == 401


from unittest.mock import patch
from fastapi.security import HTTPAuthorizationCredentials
from app.dependencies import optional_current_user


@pytest.mark.asyncio
async def test_optional_current_user_returns_none_without_token():
    """When no Authorization header is present, should return None."""
    result = await optional_current_user(credentials=None)
    assert result is None


@pytest.mark.asyncio
async def test_optional_current_user_returns_user_with_valid_token():
    """When a valid token is present, should return the user dict."""
    mock_credentials = HTTPAuthorizationCredentials(
        scheme="Bearer", credentials="valid-token"
    )
    fake_user = {"id": "user-123", "user_type": "worker", "is_active": True}

    with patch("app.dependencies.get_current_user", return_value=fake_user):
        result = await optional_current_user(credentials=mock_credentials)
        assert result == fake_user


@pytest.mark.asyncio
async def test_optional_current_user_returns_none_on_invalid_token():
    """When token is invalid/expired, should return None (not raise)."""
    mock_credentials = HTTPAuthorizationCredentials(
        scheme="Bearer", credentials="expired-token"
    )

    with patch("app.dependencies.get_current_user", side_effect=Exception("Invalid")):
        result = await optional_current_user(credentials=mock_credentials)
        assert result is None
