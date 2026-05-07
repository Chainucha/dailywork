# Supabase JWKS JWT Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace HS256 shared-secret JWT verification with RS256 JWKS-based verification using Supabase's public signing key endpoint.

**Architecture:** The backend currently decodes Supabase-issued JWTs using `python-jose` with the HS256 algorithm and a shared `SUPABASE_JWT_SECRET`. We will switch to fetching the public signing key from Supabase's JWKS endpoint (`{SUPABASE_URL}/auth/v1/.well-known/jwks.json`) and verifying with RS256. `PyJWT[crypto]` replaces `python-jose` — it ships a built-in `PyJWKClient` with automatic key caching. The HS256 secret is kept as an optional fallback for local dev / older Supabase projects.

**Tech Stack:** PyJWT[crypto], cryptography, FastAPI, Supabase Auth JWKS endpoint

---

## Current State

| Item | Detail |
|---|---|
| Library | `python-jose[cryptography]==3.3.0` |
| Algorithm | HS256 |
| Secret source | `SUPABASE_JWT_SECRET` env var (symmetric shared secret from Supabase dashboard) |
| Verification file | `backend/app/dependencies.py` |
| Config file | `backend/app/config.py` |
| No tests exist | `backend/tests/` directory is absent |

## Why Change

1. **Security** — RS256 asymmetric verification means the backend only holds the *public* key; a compromised backend cannot forge tokens.
2. **Standard practice** — Supabase exposes a JWKS endpoint; using it aligns with OpenID Connect conventions and auto-rotates keys.
3. **Simpler config** — No need to copy-paste the JWT secret into every service; just point at the JWKS URL.

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `backend/requirements.txt` | Swap `python-jose[cryptography]` for `PyJWT[crypto]` |
| Modify | `backend/app/config.py` | Add `SUPABASE_JWKS_URL`, make `SUPABASE_JWT_SECRET` optional |
| Modify | `backend/app/dependencies.py` | Rewrite `get_current_user` to verify via JWKS (RS256) with HS256 fallback |
| Modify | `backend/.env.example` | Document new env vars |
| Create | `backend/tests/__init__.py` | Package init |
| Create | `backend/tests/test_dependencies.py` | Unit tests for JWT verification logic |

**No Flutter changes required** — the client stores and sends Supabase-issued tokens; it never verifies them.

---

### Task 1: Update dependencies

**Files:**
- Modify: `backend/requirements.txt:6`

- [ ] **Step 1: Replace python-jose with PyJWT in requirements.txt**

Open `backend/requirements.txt` and replace line 6:

```
# OLD
python-jose[cryptography]==3.3.0

# NEW
PyJWT[crypto]==2.12.1
```

The full file should read:

```
fastapi==0.115.6
uvicorn[standard]==0.32.1
pydantic-settings==2.6.1
pydantic==2.10.3
supabase==2.10.0
PyJWT[crypto]==2.12.1
redis[asyncio]==5.2.1
celery==5.4.0
slowapi==0.1.9
httpx
pytest==8.3.4
pytest-asyncio==0.24.0
```

- [ ] **Step 2: Install updated dependencies**

Run:
```bash
cd backend && pip install -r requirements.txt
```

Expected: All packages install successfully. `PyJWT` 2.12.1 is installed, `python-jose` is no longer required (it may remain installed but won't be imported).

- [ ] **Step 3: Commit**

```bash
git add backend/requirements.txt
git commit -m "chore: replace python-jose with PyJWT[crypto] for JWKS support"
```

---

### Task 2: Update config to support JWKS URL

**Files:**
- Modify: `backend/app/config.py`
- Modify: `backend/.env.example`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/__init__.py` (empty) and `backend/tests/test_dependencies.py`:

```python
# backend/tests/__init__.py
```

```python
# backend/tests/test_dependencies.py
from app.config import Settings


def test_jwks_url_derived_from_supabase_url():
    """JWKS URL should default to {SUPABASE_URL}/auth/v1/.well-known/jwks.json"""
    s = Settings(
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWKS_URL == "https://abc.supabase.co/auth/v1/.well-known/jwks.json"


def test_jwt_secret_is_optional():
    """HS256 fallback secret should default to empty string."""
    s = Settings(
        SUPABASE_URL="https://abc.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY="srk",
    )
    assert s.SUPABASE_JWT_SECRET == ""
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd backend && python -m pytest tests/test_dependencies.py -v
```

Expected: FAIL — `Settings` has no field `SUPABASE_JWKS_URL`, and `SUPABASE_JWT_SECRET` is currently required.

- [ ] **Step 3: Update config.py**

Replace the full contents of `backend/app/config.py` with:

```python
from pydantic import model_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str

    # JWT — JWKS (RS256) is primary; HS256 secret is optional fallback
    SUPABASE_JWKS_URL: str = ""
    SUPABASE_JWT_SECRET: str = ""

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # App
    APP_ENV: str = "development"
    ALLOWED_ORIGINS: list[str] = ["*"]
    RATE_LIMIT_DEFAULT: str = "60/minute"

    # Firebase Cloud Messaging
    FCM_SERVER_KEY: str = ""

    @model_validator(mode="after")
    def _default_jwks_url(self) -> "Settings":
        if not self.SUPABASE_JWKS_URL:
            self.SUPABASE_JWKS_URL = (
                f"{self.SUPABASE_URL}/auth/v1/.well-known/jwks.json"
            )
        return self

    class Config:
        env_file = ".env"


settings = Settings()
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd backend && python -m pytest tests/test_dependencies.py -v
```

Expected: 2 passed.

- [ ] **Step 5: Update .env.example**

Replace the contents of `backend/.env.example` with:

```
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# JWT verification (RS256 via JWKS is primary — URL auto-derived from SUPABASE_URL if blank)
# SUPABASE_JWKS_URL=https://your-project-ref.supabase.co/auth/v1/.well-known/jwks.json
# Optional HS256 fallback (only needed if your Supabase project hasn't migrated to RS256)
# SUPABASE_JWT_SECRET=your-jwt-secret

REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/1
CELERY_RESULT_BACKEND=redis://localhost:6379/1

APP_ENV=development
ALLOWED_ORIGINS=["http://localhost:3000"]
RATE_LIMIT_DEFAULT=60/minute

FCM_SERVER_KEY=your-fcm-server-key
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/config.py backend/.env.example backend/tests/__init__.py backend/tests/test_dependencies.py
git commit -m "feat: add JWKS URL config, make JWT secret optional"
```

---

### Task 3: Rewrite JWT verification in dependencies.py

**Files:**
- Modify: `backend/app/dependencies.py`
- Modify: `backend/tests/test_dependencies.py`

- [ ] **Step 1: Write failing tests for JWKS verification**

Append to `backend/tests/test_dependencies.py`:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd backend && python -m pytest tests/test_dependencies.py -v -k "test_valid_rs256 or test_expired or test_hs256_fallback or test_no_sub"
```

Expected: FAIL — `_get_signing_key` does not exist, `jose` import errors after library swap.

- [ ] **Step 3: Rewrite dependencies.py**

Replace the full contents of `backend/app/dependencies.py` with:

```python
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
    """Try RS256 (JWKS) first, fall back to HS256 if a secret is configured."""
    # ── RS256 via JWKS ───────────────────────────────────────────
    try:
        signing_key = _get_signing_key(token)
        return pyjwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            options={"verify_aud": False},
        )
    except Exception:
        pass

    # ── HS256 fallback ───────────────────────────────────────────
    if settings.SUPABASE_JWT_SECRET:
        return pyjwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd backend && python -m pytest tests/test_dependencies.py -v
```

Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/dependencies.py backend/tests/test_dependencies.py
git commit -m "feat: switch JWT verification to RS256 via Supabase JWKS endpoint"
```

---

### Task 4: Update .env and verify end-to-end

**Files:**
- Modify: `backend/.env` (user action — not committed)

- [ ] **Step 1: Update your local .env file**

In `backend/.env`, ensure `SUPABASE_URL` is set correctly. You can remove or comment out `SUPABASE_JWT_SECRET` if your Supabase project uses RS256:

```
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
# SUPABASE_JWT_SECRET is no longer required for RS256 projects
# Uncomment the line below only if your project still uses HS256:
# SUPABASE_JWT_SECRET=<your-jwt-secret>
```

The JWKS URL will auto-derive from `SUPABASE_URL`.

- [ ] **Step 2: Start the backend and verify health**

Run:
```bash
cd backend && uvicorn app.main:app --reload --port 8000
```

Then hit:
```bash
curl http://localhost:8000/health
```

Expected: `{"status":"ok","database":"ok"}`

- [ ] **Step 3: Test auth flow end-to-end**

1. Send OTP: `POST /api/v1/auth/send-otp` with a test phone number
2. Verify OTP: `POST /api/v1/auth/verify-otp` — get back `access_token`
3. Call a protected endpoint with `Authorization: Bearer <access_token>`
4. Confirm the request succeeds (200) — the token is now verified via JWKS/RS256

- [ ] **Step 4: Run full test suite**

Run:
```bash
cd backend && python -m pytest tests/ -v
```

Expected: All tests pass.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: update env example and finalize JWKS migration"
```

---

## Summary of Changes

| Before | After |
|---|---|
| `python-jose[cryptography]` | `PyJWT[crypto]` |
| HS256 with shared `SUPABASE_JWT_SECRET` | RS256 via JWKS endpoint (auto-derived from `SUPABASE_URL`) |
| Secret required in every backend env | Only public key needed (fetched automatically) |
| No key rotation support | Automatic via JWKS cache refresh (5 min) |
| No fallback | HS256 fallback if `SUPABASE_JWT_SECRET` is set |
| No tests | Unit tests for RS256, HS256 fallback, expiry, missing claims |

## Rollback

If JWKS is unavailable (older Supabase project), set `SUPABASE_JWT_SECRET` in `.env` — the fallback path uses HS256 exactly as before.
