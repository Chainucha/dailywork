# Auth ES256 Decode Fix — Design

**Date:** 2026-04-19
**Status:** Approved for implementation planning
**Scope:** Backend JWT verification + small cleanup of probes and env

## Problem

After recent Supabase-side changes, users who complete OTP verification get `401 Unauthorized` on `POST /api/v1/auth/setup-profile` when picking a role. The job board fetch works for both guest and logged-in users; the remaining failure is purely in the role-selection step.

## Root Cause (evidence-based)

Diagnostic probes confirmed:

- Flutter log: `[auth] POST /auth/setup-profile -> token=eyJhbGciOiJFUzI1NiIs...` → token **is** attached.
- Backend log: `[jwt] decode failed: InvalidAlgorithmError: The specified alg value is not allowed`.

The JWT header `eyJhbGciOiJFUzI1NiIs...` decodes to `{"alg":"ES256",...}`. The Supabase project now signs JWTs with **ES256** (ECDSA P-256), a change from the legacy HS256.

`backend/app/dependencies.py::_decode_token` fetches the correct EC public key from JWKS, but calls `pyjwt.decode(..., algorithms=["RS256"])`. Because the allowlist contains RS256 only, PyJWT raises `InvalidAlgorithmError`. The exception propagates up, gets caught by the generic `except Exception` in `get_jwt_payload`, and is returned as 401.

The current HS256 fallback only runs when the JWKS *fetch* fails. Because the fetch succeeds, the fallback never fires.

## Goal

- `POST /auth/setup-profile` accepts Supabase ES256 tokens and returns 200.
- All other protected endpoints continue to work (`get_current_user` uses the same decode path).
- Guest browse (no token) and authenticated job board fetch continue to work.
- The decode path is robust against future Supabase algorithm rotations.

## Non-Goals

- Changing the Flutter auth flow. The probe proved tokens are attached and the state machine is correct.
- Reworking the job board fetch. It already works for both guest and authenticated states.
- Replacing PyJWT or PyJWKClient.

## Design

### Decode flow

```
                    ┌─ JWKS fetch + decode  (RS256, ES256, ES384, RS512)
  token ─decode─────┤       │ success → return payload
                    │       │ failure → fall through
                    │
                    └─ HS256 fallback (if SUPABASE_JWT_SECRET is set)
                            │ success → return payload
                            │ failure → fall through
                            │
                            └─ raise InvalidTokenError
```

### Invariants

1. A failure in any one branch never short-circuits the next. Today, an RS256 *signature* failure on a JWKS-fetched key kills the whole chain — the new design fixes that structurally, not only for ES256.
2. Callers of `_decode_token` only need to handle one exception type: `pyjwt.InvalidTokenError`. All transient JWKS network errors, key-not-found, algorithm mismatches, and signature mismatches are swallowed inside `_decode_token`.

### Algorithm allowlist (JWKS branch)

`["RS256", "ES256", "ES384", "RS512"]` — every asymmetric algorithm Supabase realistically uses. No HS256 in this branch; HS256 is symmetric and never appears via JWKS.

## Files Changed

### 1. `backend/app/dependencies.py` — the real fix

- Rewrite `_decode_token` per the flow above (JWKS broad-algorithm decode → HS256 fallback → `InvalidTokenError`).
- Remove the `jwks_unavailable` flag; the new try/except chain is simpler.
- Remove the two `[probe]` `print` lines in `get_jwt_payload`. Function signature unchanged.
- No changes to `get_current_user`, `optional_current_user`, or the role guards. They depend on `_decode_token` via the same wrapper and benefit automatically.

### 2. `backend/.env` — non-behavioral cleanup

- Rename `SUPABASE_ANON_KEY` → `SUPABASE_KEY` to match `config.py`. Removes confusion about how the anon key is resolved today.
- Delete the duplicate `SUPABASE_JWT_SECRET` line; keep one.
- No value changes.

### 3. `dailywork/lib/core/network/api_client.dart` — remove probe

- Remove the `print('[auth] ...')` line added during diagnosis in `_AuthInterceptor.onRequest`.

## Files NOT Changed (confirmed unnecessary)

- `backend/app/services/auth_service.py`, `backend/app/routers/auth.py` — already correct; `verify_otp` returns valid Supabase tokens.
- `dailywork/lib/providers/auth_provider.dart`, `dailywork/lib/screens/auth/role_select_screen.dart`, `dailywork/lib/repositories/api/api_auth_repository.dart` — Flutter-side flow is correct; probe proved tokens are attached.
- Job board code (`api_job_repository.dart`, `job_cache_provider.dart`, `routers/jobs.py`, `services/job_service.py`) — already working in both guest and authenticated states.

## Verification Plan

### Golden path (end-to-end manual)

1. Restart backend (`uvicorn app.main:app --reload --port 8000`) and hot-restart Flutter (`R`).
2. **Guest browse:** launch app → land on `/browse` → job feed renders. Confirms the `optional_current_user` path still works (no token).
3. **New user signup:** phone login → OTP → `/select-role` → tap **Worker** → land on `/worker/home` with data loading. Confirms `setup-profile` 401 is gone.
4. **Returning user:** logout → re-login with the same phone → skip `/select-role` → land on `/worker/home`. Confirms `get_current_user` (which also uses `_decode_token`) decodes ES256 correctly.
5. **Logged-in fetch:** `/users/me` in Flutter console succeeds (no 401). Confirms the `get_current_user` path.

### Negative cases (no regression)

- Mangled bearer token → expect 401 `Invalid or expired token`.
- Missing `Authorization` header on a protected endpoint → expect 403 `Not authenticated` (from `HTTPBearer`).

### Log discipline

After the fix, uvicorn shows **no `[jwt]` lines** (probes removed) and `200 OK` on `POST /api/v1/auth/setup-profile`.

## Rollback Trigger

If any of steps 2–5 of the golden path regresses — particularly step 4, which exercises the full `get_current_user` path — revert the `_decode_token` change and re-open diagnosis. The `.env` cleanup and Flutter-probe removal are independent and safe to keep.

## Risks

- **Broader algorithm allowlist:** enlarges the set of accepted signature algorithms from `{RS256, HS256}` to `{RS256, ES256, ES384, RS512, HS256}`. All five are cryptographically sound; the risk is acceptable and matches Supabase's realistic key set.
- **Swallowing JWKS errors:** the new design catches JWKS network failures and falls through to HS256 if configured. In principle this could mask a real JWKS outage. Acceptable because `SUPABASE_JWT_SECRET` is only set in dev; production deployments without the fallback will still raise `InvalidTokenError` on a JWKS outage, which surfaces as 401.
