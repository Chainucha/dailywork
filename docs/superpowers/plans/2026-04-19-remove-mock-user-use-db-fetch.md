# Remove Mock User, Use DB Fetch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete `dailywork/lib/repositories/mock_users.dart` and replace every remaining stub on the worker/employer profile screens with real data fetched from the backend. Adds a `users.display_name` column, onboarding name-entry flow, edit-name dialog, computed `jobs_completed` / `jobs_posted`, and a paginated `GET /users/{user_id}/reviews` endpoint.

**Architecture:** Single bundled PR, backend-first. One Supabase migration, four extended endpoints + one rewritten endpoint, a Flutter model refactor, a new `ApiReviewRepository` + `NameEntryScreen`, and surgical changes to two profile screens. Reliability and experience-years fields are dropped outright. Employers do not get an edit-name icon because their displayed name comes from `business_name`, not `display_name`.

**Tech Stack:** FastAPI (Python 3.11), Pydantic v2, supabase-py, pytest, FastAPI TestClient, Supabase PostgreSQL 15, Flutter 3.x, Dart, Riverpod, Dio, go_router.

**Spec:** `docs/superpowers/specs/2026-04-19-remove-mock-user-use-db-fetch-design.md`

---

## File Structure

### Created

| Path | Responsibility |
|---|---|
| `backend/supabase/migrations/006_add_users_display_name.sql` | DB migration adding nullable `display_name` column |
| `dailywork/lib/repositories/api/api_review_repository.dart` | Flutter repo + `Review` / `ReviewPage` DTOs for reviews-of-a-user fetch |
| `dailywork/lib/screens/auth/name_entry_screen.dart` | Two-mode screen: onboarding name capture + edit-name dialog |
| `backend/tests/test_users_display_name.py` | Tests for PATCH `/users/me` display_name validation |
| `backend/tests/test_workers_jobs_completed.py` | Tests for computed `jobs_completed` in worker profile |
| `backend/tests/test_employers_jobs_posted.py` | Tests for computed `jobs_posted` in employer profile |
| `backend/tests/test_users_reviews_pagination.py` | Tests for paginated reviews-of-a-user endpoint |
| `backend/tests/test_setup_profile_display_name.py` | Tests for optional `display_name` on `POST /auth/setup-profile` |
| `dailywork/test/models/user_model_test.dart` | Tests for `UserModel.fromJson` display name precedence |

### Modified

| Path | What changes |
|---|---|
| `backend/app/schemas/users.py` | Add `display_name` to `UserResponse` + `UserUpdate` (with trim + length validation) |
| `backend/app/schemas/workers.py` | Add `jobs_completed: int` to `WorkerProfileResponse` |
| `backend/app/schemas/employers.py` | Add `jobs_posted: int` to `EmployerProfileResponse` |
| `backend/app/schemas/auth.py` | Add optional `display_name` to `SetupProfileRequest` |
| `backend/app/services/auth_service.py` | `setup_profile` accepts + stores `display_name` |
| `backend/app/routers/auth.py` | Pass `body.display_name` through to service |
| `backend/app/routers/users.py` | Rewrite `GET /{user_id}/reviews` for pagination + `reviewer_display_name` flattening |
| `backend/app/routers/workers.py` | Compute and attach `jobs_completed` in both profile endpoints |
| `backend/app/routers/employers.py` | Compute and attach `jobs_posted` in both profile endpoints |
| `dailywork/lib/models/user_model.dart` | Remove `reliabilityPercent`/`experienceYears`; add `jobsCompleted`/`jobsPosted`; fix `displayName` precedence |
| `dailywork/lib/repositories/api/api_user_repository.dart` | Add `updateDisplayName(String)` |
| `dailywork/lib/repositories/api/api_auth_repository.dart` | Widen `setupProfile` with optional `displayName` |
| `dailywork/lib/providers/auth_provider.dart` | Widen `setupProfile`; add `refreshMe` |
| `dailywork/lib/core/router/app_router.dart` | Register `/name-entry` route with typed argument |
| `dailywork/lib/screens/auth/role_select_screen.dart` | Worker branch pushes to `/name-entry` instead of calling `setupProfile` directly |
| `dailywork/lib/screens/worker/worker_profile_screen.dart` | Drop mock import; add edit icon; Reliability row dropped; Experience row swapped for Reviews; Reviews section uses provider |
| `dailywork/lib/screens/employer/employer_profile_screen.dart` | Real `jobsPosted`; no edit-name icon |

### Deleted

| Path | Why |
|---|---|
| `dailywork/lib/repositories/mock_users.dart` | Last remaining mock-user source |

---

## Backend Test Harness Conventions

- All backend tests use `TestClient(app)` from `backend/tests/test_public_endpoints.py` as a reference. Import: `from fastapi.testclient import TestClient; from app.main import app; client = TestClient(app)`.
- Auth-protected endpoints are tested by overriding dependencies:

  ```python
  from app.main import app
  from app.dependencies import get_current_user, require_worker, require_employer

  FAKE_WORKER = {
      "id": "11111111-1111-1111-1111-111111111111",
      "phone_number": "+15551112222",
      "user_type": "worker",
      "display_name": None,
  }

  @pytest.fixture
  def override_worker():
      app.dependency_overrides[get_current_user] = lambda: FAKE_WORKER
      app.dependency_overrides[require_worker] = lambda: FAKE_WORKER
      yield
      app.dependency_overrides.clear()
  ```

- DB interactions: tests rely on a live dev Supabase (same as existing `test_public_endpoints.py`). Tests that write/read need to seed via `get_supabase()` and clean up afterwards. Use `pytest.fixture(scope="function")` with teardown to delete seeded rows.

- If your environment does not have Supabase reachable, tests can be skipped with `pytest.importorskip` or `@pytest.mark.skipif`. Do not mock the Supabase client — the goal is real DB verification.

---

## Task 1: DB Migration — add `users.display_name`

**Files:**
- Create: `backend/supabase/migrations/006_add_users_display_name.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- 006_add_users_display_name.sql
-- Adds a nullable display_name column to users. Existing rows remain NULL.
-- Flutter falls back to phone_number when NULL; new worker onboarding
-- enforces a non-empty value; employers use business_name instead.

ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Length guard at the DB level; also enforced in Pydantic.
ALTER TABLE users
  ADD CONSTRAINT users_display_name_length
  CHECK (display_name IS NULL OR char_length(display_name) BETWEEN 1 AND 60);
```

- [ ] **Step 2: Apply the migration**

Run in repo root:

```bash
cd backend && supabase db push
```

Expected: `Applied 006_add_users_display_name.sql`. No error.

- [ ] **Step 3: Verify the column exists**

Run in repo root (Supabase SQL editor or CLI):

```bash
supabase db query "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='users' AND column_name='display_name'"
```

Expected: One row, `text`, `YES`.

- [ ] **Step 4: Verify the CHECK constraint rejects invalid lengths**

```bash
supabase db query "INSERT INTO users (phone_number, user_type, display_name) VALUES ('+10000000001','worker','') RETURNING id" 2>&1 | head -5
```

Expected: error mentioning `users_display_name_length`. If it succeeded, delete the row and the constraint is broken — re-check.

Clean up any row you created:
```bash
supabase db query "DELETE FROM users WHERE phone_number LIKE '+1000000000%'"
```

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations/006_add_users_display_name.sql
git commit -m "feat(db): add users.display_name nullable column with length check"
```

---

## Task 2: Extend `UserResponse` + `UserUpdate` schemas

**Files:**
- Modify: `backend/app/schemas/users.py`
- Test: `backend/tests/test_users_display_name.py` (new file)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_users_display_name.py`:

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user

client = TestClient(app)

FAKE_USER = {
    "id": "11111111-1111-1111-1111-111111111111",
    "phone_number": "+15551112222",
    "user_type": "worker",
    "display_name": None,
    "location_lat": None,
    "location_lng": None,
    "created_at": "2026-04-19T00:00:00+00:00",
}


@pytest.fixture
def override_user():
    app.dependency_overrides[get_current_user] = lambda: FAKE_USER
    yield
    app.dependency_overrides.clear()


def test_user_update_rejects_empty_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": ""})
    assert res.status_code == 422


def test_user_update_rejects_whitespace_only_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": "   "})
    assert res.status_code == 422


def test_user_update_rejects_too_long_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": "x" * 61})
    assert res.status_code == 422


def test_user_update_accepts_valid_display_name(override_user):
    # Trim is applied server-side; the value eventually reaches Supabase.
    # Since we can't verify the DB side in this unit scope, we assert the
    # request is not rejected by validation (422).
    res = client.patch("/api/v1/users/me", json={"display_name": "  Alice  "})
    # Either 200 (DB reachable) or 500 (DB unreachable in local dev) — both
    # indicate validation passed. 422 would mean we rejected a valid name.
    assert res.status_code != 422
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_users_display_name.py -v
```

Expected: all four fail — the current `UserUpdate` schema has no `display_name` field so Pydantic silently ignores it and the PATCH returns 200 with no update (never 422).

- [ ] **Step 3: Update `UserResponse` and `UserUpdate` schemas**

Edit `backend/app/schemas/users.py` — replace full contents:

```python
from pydantic import BaseModel, UUID4, field_validator
from datetime import datetime
from typing import Literal


class UserResponse(BaseModel):
    id: UUID4
    phone_number: str
    user_type: Literal["worker", "employer"]
    display_name: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    fcm_token: str | None = None

    @field_validator("display_name")
    @classmethod
    def _validate_display_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("display_name cannot be empty or whitespace")
        if len(trimmed) > 60:
            raise ValueError("display_name cannot exceed 60 characters")
        return trimmed
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_users_display_name.py -v
```

Expected: all four pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/users.py backend/tests/test_users_display_name.py
git commit -m "feat(users): add display_name to user schemas with trim + length validation"
```

---

## Task 3: Add `jobs_completed` field to `WorkerProfileResponse`

**Files:**
- Modify: `backend/app/schemas/workers.py`

- [ ] **Step 1: Edit the schema**

Replace the contents of `backend/app/schemas/workers.py` with:

```python
from pydantic import BaseModel, UUID4
from datetime import datetime


class WorkerProfileResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    skills: list[str]
    availability_status: bool
    daily_wage_expectation: float | None = None
    rating_avg: float
    total_reviews: int
    jobs_completed: int = 0   # NEW — computed at the endpoint, defaulted to 0
    updated_at: datetime


class WorkerProfileUpdate(BaseModel):
    skills: list[str] | None = None
    availability_status: bool | None = None
    daily_wage_expectation: float | None = None
```

- [ ] **Step 2: Run existing worker tests to confirm no regression**

```bash
cd backend && pytest tests/ -v -k worker
```

Expected: existing tests pass (no test currently asserts on `jobs_completed`, so the default 0 keeps them green).

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas/workers.py
git commit -m "feat(workers): add jobs_completed to WorkerProfileResponse schema"
```

---

## Task 4: Add `jobs_posted` field to `EmployerProfileResponse`

**Files:**
- Modify: `backend/app/schemas/employers.py`

- [ ] **Step 1: Edit the schema**

Replace the contents of `backend/app/schemas/employers.py` with:

```python
from pydantic import BaseModel, UUID4
from datetime import datetime


class EmployerProfileResponse(BaseModel):
    id: UUID4
    user_id: UUID4
    business_name: str
    business_type: str | None = None
    rating_avg: float
    total_reviews: int
    jobs_posted: int = 0   # NEW — computed at the endpoint, defaulted to 0
    updated_at: datetime


class EmployerProfileUpdate(BaseModel):
    business_name: str | None = None
    business_type: str | None = None
```

- [ ] **Step 2: Run existing employer tests to confirm no regression**

```bash
cd backend && pytest tests/ -v -k employer
```

Expected: no existing employer tests fail.

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas/employers.py
git commit -m "feat(employers): add jobs_posted to EmployerProfileResponse schema"
```

---

## Task 5: Compute `jobs_completed` in both workers endpoints

**Files:**
- Modify: `backend/app/routers/workers.py`
- Test: `backend/tests/test_workers_jobs_completed.py` (new file)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_workers_jobs_completed.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_worker
from app.supabase_client import get_supabase

client = TestClient(app)


def _seed_worker_with_jobs(db, *, completed_accepted: int, other: int) -> dict:
    """Seed a worker + N accepted-on-completed-job applications + N other-status apps."""
    worker_id = str(uuid.uuid4())
    employer_id = str(uuid.uuid4())
    db.table("users").insert([
        {"id": worker_id, "phone_number": f"+1{worker_id[:10]}", "user_type": "worker"},
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer"},
    ]).execute()
    db.table("worker_profiles").insert({"user_id": worker_id}).execute()
    db.table("employer_profiles").insert(
        {"user_id": employer_id, "business_name": "TestCo"}
    ).execute()

    # Need a category
    cat = db.table("categories").select("id").limit(1).execute()
    category_id = cat.data[0]["id"]

    # Seed completed jobs + accepted applications
    for _ in range(completed_accepted):
        job = db.table("jobs").insert({
            "employer_id": employer_id,
            "category_id": category_id,
            "title": "test",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": "completed",
        }).execute()
        db.table("applications").insert({
            "job_id": job.data[0]["id"],
            "worker_id": worker_id,
            "status": "accepted",
        }).execute()

    # Seed other rows that must NOT be counted:
    #  - accepted on in_progress job
    #  - pending on completed job
    for _ in range(other):
        job = db.table("jobs").insert({
            "employer_id": employer_id,
            "category_id": category_id,
            "title": "test-ip",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": "in_progress",
        }).execute()
        db.table("applications").insert({
            "job_id": job.data[0]["id"],
            "worker_id": worker_id,
            "status": "accepted",
        }).execute()

    return {"worker_id": worker_id, "employer_id": employer_id}


def _cleanup(db, worker_id: str, employer_id: str):
    db.table("applications").delete().eq("worker_id", worker_id).execute()
    db.table("jobs").delete().eq("employer_id", employer_id).execute()
    db.table("worker_profiles").delete().eq("user_id", worker_id).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("users").delete().in_("id", [worker_id, employer_id]).execute()


@pytest.fixture
def seeded_worker():
    db = get_supabase()
    ids = _seed_worker_with_jobs(db, completed_accepted=2, other=1)
    yield ids
    _cleanup(db, **ids)


def test_workers_me_profile_returns_jobs_completed(seeded_worker):
    fake_user = {"id": seeded_worker["worker_id"], "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_worker] = lambda: fake_user
    try:
        res = client.get("/api/v1/workers/me/profile")
        assert res.status_code == 200
        body = res.json()
        assert body["jobs_completed"] == 2
    finally:
        app.dependency_overrides.clear()


def test_workers_public_profile_returns_jobs_completed(seeded_worker):
    fake_reader = {"id": "22222222-2222-2222-2222-222222222222", "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_reader
    try:
        res = client.get(f"/api/v1/workers/{seeded_worker['worker_id']}/profile")
        assert res.status_code == 200
        assert res.json()["jobs_completed"] == 2
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_workers_jobs_completed.py -v
```

Expected: both fail — response has no `jobs_completed` field, or it's always 0.

- [ ] **Step 3: Update the workers router**

Replace `backend/app/routers/workers.py` with:

```python
from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user, require_worker
from app.schemas.workers import WorkerProfileResponse, WorkerProfileUpdate
from app.supabase_client import get_supabase

router = APIRouter(tags=["workers"])


def _count_jobs_completed(db, worker_id: str) -> int:
    """Count applications where worker was accepted AND the job is completed."""
    result = (
        db.table("applications")
        .select("id, jobs!inner(status)", count="exact")
        .eq("worker_id", worker_id)
        .eq("status", "accepted")
        .eq("jobs.status", "completed")
        .execute()
    )
    return result.count or 0


@router.get("/me/profile", response_model=WorkerProfileResponse)
async def get_my_profile(current_user: dict = Depends(require_worker)):
    db = get_supabase()
    result = db.table("worker_profiles").select("*").eq("user_id", current_user["id"]).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Worker profile not found")
    profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, current_user["id"])
    return profile


@router.patch("/me/profile", response_model=WorkerProfileResponse)
async def update_my_profile(
    body: WorkerProfileUpdate,
    current_user: dict = Depends(require_worker),
):
    db = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        result = db.table("worker_profiles").select("*").eq("user_id", current_user["id"]).execute()
        profile = result.data[0]
    else:
        result = (
            db.table("worker_profiles")
            .update(updates)
            .eq("user_id", current_user["id"])
            .execute()
        )
        profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, current_user["id"])
    return profile


@router.get("/{user_id}/profile", response_model=WorkerProfileResponse)
async def get_worker_profile(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("worker_profiles").select("*").eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Worker profile not found")
    profile = result.data[0]
    profile["jobs_completed"] = _count_jobs_completed(db, user_id)
    return profile
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_workers_jobs_completed.py -v
```

Expected: both pass. If the `jobs!inner(status)` embedded filter yields 0 when it should yield 2, check that `applications.job_id` FK points at `jobs.id` (it does per `001_create_tables.sql`) — the inner-join syntax relies on that FK.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/workers.py backend/tests/test_workers_jobs_completed.py
git commit -m "feat(workers): compute jobs_completed in worker profile endpoints"
```

---

## Task 6: Compute `jobs_posted` in both employers endpoints

**Files:**
- Modify: `backend/app/routers/employers.py`
- Test: `backend/tests/test_employers_jobs_posted.py` (new file)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_employers_jobs_posted.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_employer
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_employer():
    db = get_supabase()
    employer_id = str(uuid.uuid4())
    db.table("users").insert(
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": employer_id, "business_name": "TestCo"}
    ).execute()
    category_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]

    # 4 jobs across statuses — all should be counted
    for status in ["open", "assigned", "completed", "cancelled"]:
        db.table("jobs").insert({
            "employer_id": employer_id,
            "category_id": category_id,
            "title": f"test-{status}",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": status,
        }).execute()

    yield employer_id

    db.table("jobs").delete().eq("employer_id", employer_id).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("users").delete().eq("id", employer_id).execute()


def test_employers_me_profile_returns_jobs_posted(seeded_employer):
    fake_user = {"id": seeded_employer, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.get("/api/v1/employers/me/profile")
        assert res.status_code == 200
        assert res.json()["jobs_posted"] == 4
    finally:
        app.dependency_overrides.clear()


def test_employers_public_profile_returns_jobs_posted(seeded_employer):
    fake_reader = {"id": "33333333-3333-3333-3333-333333333333", "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake_reader
    try:
        res = client.get(f"/api/v1/employers/{seeded_employer}/profile")
        assert res.status_code == 200
        assert res.json()["jobs_posted"] == 4
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_employers_jobs_posted.py -v
```

Expected: both fail — no `jobs_posted` field in the response.

- [ ] **Step 3: Update the employers router**

Replace `backend/app/routers/employers.py` with:

```python
from fastapi import APIRouter, Depends, HTTPException
from app.dependencies import get_current_user, require_employer
from app.schemas.employers import EmployerProfileResponse, EmployerProfileUpdate
from app.supabase_client import get_supabase

router = APIRouter(tags=["employers"])


def _count_jobs_posted(db, employer_id: str) -> int:
    result = (
        db.table("jobs")
        .select("id", count="exact")
        .eq("employer_id", employer_id)
        .execute()
    )
    return result.count or 0


@router.get("/me/profile", response_model=EmployerProfileResponse)
async def get_my_profile(current_user: dict = Depends(require_employer)):
    db = get_supabase()
    result = db.table("employer_profiles").select("*").eq("user_id", current_user["id"]).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, current_user["id"])
    return profile


@router.patch("/me/profile", response_model=EmployerProfileResponse)
async def update_my_profile(
    body: EmployerProfileUpdate,
    current_user: dict = Depends(require_employer),
):
    db = get_supabase()
    updates = body.model_dump(exclude_none=True)
    if not updates:
        result = db.table("employer_profiles").select("*").eq("user_id", current_user["id"]).execute()
        profile = result.data[0]
    else:
        result = (
            db.table("employer_profiles")
            .update(updates)
            .eq("user_id", current_user["id"])
            .execute()
        )
        profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, current_user["id"])
    return profile


@router.get("/{user_id}/profile", response_model=EmployerProfileResponse)
async def get_employer_profile(
    user_id: str,
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()
    result = db.table("employer_profiles").select("*").eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Employer profile not found")
    profile = result.data[0]
    profile["jobs_posted"] = _count_jobs_posted(db, user_id)
    return profile
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_employers_jobs_posted.py -v
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/employers.py backend/tests/test_employers_jobs_posted.py
git commit -m "feat(employers): compute jobs_posted in employer profile endpoints"
```

---

## Task 7: Accept `display_name` on `POST /auth/setup-profile`

**Files:**
- Modify: `backend/app/schemas/auth.py`
- Modify: `backend/app/services/auth_service.py`
- Modify: `backend/app/routers/auth.py`
- Test: `backend/tests/test_setup_profile_display_name.py` (new file)

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_setup_profile_display_name.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_jwt_payload
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def fresh_user_jwt():
    user_id = str(uuid.uuid4())
    phone = f"+1{user_id[:10]}"
    app.dependency_overrides[get_jwt_payload] = lambda: {"sub": user_id, "phone": phone}
    yield {"sub": user_id, "phone": phone}
    db = get_supabase()
    # Cleanup — setup_profile inserts into users and worker_profiles/employer_profiles
    db.table("worker_profiles").delete().eq("user_id", user_id).execute()
    db.table("employer_profiles").delete().eq("user_id", user_id).execute()
    db.table("users").delete().eq("id", user_id).execute()
    app.dependency_overrides.clear()


def test_setup_profile_stores_display_name(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "worker", "display_name": "Alice"},
    )
    assert res.status_code == 200

    db = get_supabase()
    row = db.table("users").select("display_name").eq("id", fresh_user_jwt["sub"]).execute()
    assert row.data[0]["display_name"] == "Alice"


def test_setup_profile_without_display_name_leaves_null(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "employer"},
    )
    assert res.status_code == 200

    db = get_supabase()
    row = db.table("users").select("display_name").eq("id", fresh_user_jwt["sub"]).execute()
    assert row.data[0]["display_name"] is None


def test_setup_profile_rejects_empty_display_name(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "worker", "display_name": "   "},
    )
    assert res.status_code == 422
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_setup_profile_display_name.py -v
```

Expected: all three fail — the schema currently doesn't know about `display_name`, so the first test's read returns `None`, the third test gets 200 instead of 422.

- [ ] **Step 3: Update `SetupProfileRequest` schema**

Edit `backend/app/schemas/auth.py` — replace the `SetupProfileRequest` class:

```python
class SetupProfileRequest(BaseModel):
    user_type: Literal["worker", "employer"]
    display_name: str | None = None

    @field_validator("display_name")
    @classmethod
    def _validate_display_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("display_name cannot be empty or whitespace")
        if len(trimmed) > 60:
            raise ValueError("display_name cannot exceed 60 characters")
        return trimmed
```

Also add to the top imports of the same file:

```python
from pydantic import BaseModel, field_validator
from typing import Literal
```

(Keep existing imports if they differ — merge, don't overwrite.)

- [ ] **Step 4: Update `auth_service.setup_profile`**

Edit `backend/app/services/auth_service.py` — replace the `setup_profile` function:

```python
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
```

- [ ] **Step 5: Update the auth router**

Edit `backend/app/routers/auth.py` — replace the `setup_profile` endpoint:

```python
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
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_setup_profile_display_name.py -v
```

Expected: all three pass.

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/auth.py backend/app/services/auth_service.py backend/app/routers/auth.py backend/tests/test_setup_profile_display_name.py
git commit -m "feat(auth): accept optional display_name on setup-profile"
```

---

## Task 8: Paginate `GET /users/{user_id}/reviews`

**Files:**
- Modify: `backend/app/routers/users.py`
- Modify: `backend/app/schemas/reviews.py`
- Test: `backend/tests/test_users_reviews_pagination.py` (new file)

**Context:** The endpoint already exists at `GET /api/v1/users/{user_id}/reviews` and currently returns `{"data": [...]}` with the reviewer embedded as a sub-object (`reviewer: {id, phone_number, user_type}`). This task rewrites it to return `{items, total, limit, offset}`, flattens `reviewer_display_name`, and adds query-param pagination.

- [ ] **Step 1: Extend `backend/app/schemas/reviews.py`**

Append to `backend/app/schemas/reviews.py`:

```python
class ReviewListItem(BaseModel):
    id: UUID4
    rating: int
    comment: str | None = None
    created_at: datetime
    reviewer_display_name: str


class ReviewListResponse(BaseModel):
    items: list[ReviewListItem]
    total: int
    limit: int
    offset: int
```

- [ ] **Step 2: Write the failing test**

Create `backend/tests/test_users_reviews_pagination.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_reviews():
    """Seed a reviewee and 25 reviewers with one review each."""
    db = get_supabase()
    reviewee_id = str(uuid.uuid4())
    employer_id = str(uuid.uuid4())

    # Reviewee (worker) + employer posting a job
    db.table("users").insert([
        {"id": reviewee_id, "phone_number": f"+1{reviewee_id[:10]}", "user_type": "worker"},
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer", "display_name": "Prestige"},
    ]).execute()
    db.table("worker_profiles").insert({"user_id": reviewee_id}).execute()
    db.table("employer_profiles").insert({"user_id": employer_id, "business_name": "Prestige"}).execute()

    category_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]

    # One completed job + 25 reviews by distinct reviewers
    job = db.table("jobs").insert({
        "employer_id": employer_id,
        "category_id": category_id,
        "title": "job", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 1,
        "start_date": "2026-01-01", "end_date": "2026-01-02",
        "status": "completed",
    }).execute().data[0]

    reviewer_ids = []
    for i in range(25):
        rid = str(uuid.uuid4())
        reviewer_ids.append(rid)
        # Reviewers alternate: first 15 have a display_name, last 10 do not
        display_name = f"Reviewer {i}" if i < 15 else None
        db.table("users").insert({
            "id": rid,
            "phone_number": f"+1900{i:07d}",
            "user_type": "employer",
            "display_name": display_name,
        }).execute()
        db.table("reviews").insert({
            "reviewer_id": rid,
            "reviewee_id": reviewee_id,
            "job_id": job["id"],
            "rating": (i % 5) + 1,
            "comment": f"comment {i}",
        }).execute()

    yield {"reviewee_id": reviewee_id, "reviewer_ids": reviewer_ids, "employer_id": employer_id, "job_id": job["id"]}

    db.table("reviews").delete().eq("reviewee_id", reviewee_id).execute()
    db.table("jobs").delete().eq("id", job["id"]).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("worker_profiles").delete().eq("user_id", reviewee_id).execute()
    db.table("users").delete().in_("id", reviewer_ids + [reviewee_id, employer_id]).execute()


@pytest.fixture
def any_auth():
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "44444444-4444-4444-4444-444444444444", "user_type": "worker",
    }
    yield
    app.dependency_overrides.clear()


def test_reviews_default_pagination_returns_20(seeded_reviews, any_auth):
    res = client.get(f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews")
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 25
    assert body["limit"] == 20
    assert body["offset"] == 0
    assert len(body["items"]) == 20


def test_reviews_respects_limit_and_offset(seeded_reviews, any_auth):
    res = client.get(
        f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
        params={"limit": 10, "offset": 20},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 25
    assert len(body["items"]) == 5


def test_reviews_flattens_reviewer_display_name(seeded_reviews, any_auth):
    res = client.get(f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
                     params={"limit": 50, "offset": 0})
    items = res.json()["items"]
    assert len(items) == 25
    # Reviewers 0..14 have display_name; 15..24 fall back to phone_number.
    named = [i for i in items if i["reviewer_display_name"].startswith("Reviewer ")]
    phone_fallback = [i for i in items if i["reviewer_display_name"].startswith("+1900")]
    assert len(named) == 15
    assert len(phone_fallback) == 10


def test_reviews_rejects_limit_over_50(seeded_reviews, any_auth):
    res = client.get(
        f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
        params={"limit": 51, "offset": 0},
    )
    assert res.status_code == 422
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_users_reviews_pagination.py -v
```

Expected: all four fail — current endpoint returns `{"data": [...]}`, not the envelope shape, and does not accept `limit` or `offset`.

- [ ] **Step 4: Rewrite the endpoint**

Edit `backend/app/routers/users.py` — replace the existing `get_user_reviews` function:

```python
from fastapi import APIRouter, Depends, HTTPException, Query
from app.dependencies import get_current_user
from app.schemas.users import UserResponse, UserUpdate
from app.schemas.reviews import ReviewListResponse
from app.supabase_client import get_supabase

router = APIRouter(tags=["users"])


# ... keep existing get_me, update_me, get_user ...


@router.get("/{user_id}/reviews", response_model=ReviewListResponse)
async def get_user_reviews(
    user_id: str,
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    db = get_supabase()

    # Two queries: one for the page, one for the total count.
    page = (
        db.table("reviews")
        .select("id, rating, comment, created_at, reviewer:reviewer_id(display_name, phone_number)")
        .eq("reviewee_id", user_id)
        .order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    total_result = (
        db.table("reviews")
        .select("id", count="exact")
        .eq("reviewee_id", user_id)
        .execute()
    )

    items = []
    for r in page.data:
        reviewer = r.get("reviewer") or {}
        items.append({
            "id": r["id"],
            "rating": r["rating"],
            "comment": r["comment"],
            "created_at": r["created_at"],
            "reviewer_display_name": reviewer.get("display_name") or reviewer.get("phone_number") or "",
        })

    return {
        "items": items,
        "total": total_result.count or 0,
        "limit": limit,
        "offset": offset,
    }
```

Keep the existing `get_me`, `update_me`, `get_user` functions as-is; only the reviews endpoint changes. Full file after the change should have imports at the top consolidated (Query added).

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_users_reviews_pagination.py -v
```

Expected: all four pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/users.py backend/app/schemas/reviews.py backend/tests/test_users_reviews_pagination.py
git commit -m "feat(users): paginate GET /users/{id}/reviews with flattened reviewer_display_name"
```

---

## Task 9: Update Flutter `UserModel` + profile classes

**Files:**
- Modify: `dailywork/lib/models/user_model.dart`
- Test: `dailywork/test/models/user_model_test.dart` (new file)

- [ ] **Step 1: Write the failing test**

Create `dailywork/test/models/user_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywork/models/user_model.dart';

void main() {
  group('UserModel.fromJson displayName precedence', () {
    test('employer uses business_name over display_name', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+1555',
        'user_type': 'employer',
        'display_name': 'Personal Name',
        'business_name': 'Acme Co',
      });
      expect(u.displayName, 'Acme Co');
    });

    test('worker uses display_name when present', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+1555',
        'user_type': 'worker',
        'display_name': 'Alice',
      });
      expect(u.displayName, 'Alice');
    });

    test('falls back to phone_number when display_name is null', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+15551112222',
        'user_type': 'worker',
        'display_name': null,
      });
      expect(u.displayName, '+15551112222');
    });
  });

  group('WorkerProfile.fromJson', () {
    test('reads jobs_completed from payload', () {
      final p = WorkerProfile.fromJson({
        'skills': ['Plumbing'],
        'availability_status': true,
        'rating_avg': 4.5,
        'total_reviews': 10,
        'jobs_completed': 7,
      });
      expect(p.jobsCompleted, 7);
      expect(p.skills, ['Plumbing']);
    });

    test('defaults jobs_completed to 0 when missing', () {
      final p = WorkerProfile.fromJson({
        'skills': [],
        'availability_status': true,
        'rating_avg': 0,
        'total_reviews': 0,
      });
      expect(p.jobsCompleted, 0);
    });
  });

  group('EmployerProfile.fromJson', () {
    test('reads jobs_posted from payload', () {
      final p = EmployerProfile.fromJson({
        'business_name': 'Acme',
        'rating_avg': 4.0,
        'total_reviews': 5,
        'jobs_posted': 12,
      });
      expect(p.jobsPosted, 12);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd dailywork && flutter test test/models/user_model_test.dart
```

Expected: compilation errors — `jobsPosted` doesn't exist on `EmployerProfile`, `displayName` resolution is wrong for employers, etc.

- [ ] **Step 3: Rewrite `user_model.dart`**

Replace the full contents of `dailywork/lib/models/user_model.dart` with:

```dart
enum UserRole { worker, employer }

class WorkerProfile {
  final List<String> skills;
  final bool availabilityStatus;
  final double? dailyWageExpectation;
  final int jobsCompleted;
  final double ratingAvg;
  final int totalReviews;

  const WorkerProfile({
    required this.skills,
    required this.availabilityStatus,
    this.dailyWageExpectation,
    required this.jobsCompleted,
    required this.ratingAvg,
    required this.totalReviews,
  });

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
        skills: (json['skills'] as List<dynamic>? ?? []).cast<String>(),
        availabilityStatus: json['availability_status'] as bool? ?? true,
        dailyWageExpectation:
            (json['daily_wage_expectation'] as num?)?.toDouble(),
        jobsCompleted: json['jobs_completed'] as int? ?? 0,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
        totalReviews: json['total_reviews'] as int? ?? 0,
      );
}

class EmployerProfile {
  final String businessName;
  final String? businessType;
  final int jobsPosted;
  final double ratingAvg;
  final int totalReviews;

  const EmployerProfile({
    required this.businessName,
    this.businessType,
    required this.jobsPosted,
    required this.ratingAvg,
    required this.totalReviews,
  });

  factory EmployerProfile.fromJson(Map<String, dynamic> json) => EmployerProfile(
        businessName: json['business_name'] as String? ?? '',
        businessType: json['business_type'] as String?,
        jobsPosted: json['jobs_posted'] as int? ?? 0,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
        totalReviews: json['total_reviews'] as int? ?? 0,
      );
}

class UserModel {
  final String id;
  final String phoneNumber;
  final UserRole role;
  final String displayName;
  final WorkerProfile? workerProfile;
  final EmployerProfile? employerProfile;

  const UserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    required this.displayName,
    this.workerProfile,
    this.employerProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userType = json['user_type'] as String;
    final role = userType == 'employer' ? UserRole.employer : UserRole.worker;

    // Precedence: employer business_name → users.display_name → phone_number.
    final businessName = json['business_name'] as String?;
    final storedDisplayName = json['display_name'] as String?;
    final phone = json['phone_number'] as String;
    final resolved = (role == UserRole.employer && businessName != null && businessName.isNotEmpty)
        ? businessName
        : (storedDisplayName != null && storedDisplayName.isNotEmpty)
            ? storedDisplayName
            : phone;

    return UserModel(
      id: json['id'] as String,
      phoneNumber: phone,
      role: role,
      displayName: resolved,
      workerProfile: role == UserRole.worker ? WorkerProfile.fromJson(json) : null,
      employerProfile: role == UserRole.employer ? EmployerProfile.fromJson(json) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd dailywork && flutter test test/models/user_model_test.dart
```

Expected: all pass.

- [ ] **Step 5: Check the rest of the app still compiles**

```bash
cd dailywork && flutter analyze
```

Expected: only pre-existing issues (not introduced by this task). If `WorkerProfileScreen` complains about missing `reliabilityPercent` / `experienceYears` — that is expected and will be fixed in Task 15. Do not fix it yet. If `mock_users.dart` now fails to compile (it references `reliabilityPercent: 98`), that's also expected — will be deleted in Task 17.

- [ ] **Step 6: Commit**

```bash
git add dailywork/lib/models/user_model.dart dailywork/test/models/user_model_test.dart
git commit -m "refactor(user-model): drop reliability/experience, add jobsCompleted/jobsPosted, fix displayName precedence"
```

---

## Task 10: Add `updateDisplayName` to `ApiUserRepository`

**Files:**
- Modify: `dailywork/lib/repositories/api/api_user_repository.dart`

- [ ] **Step 1: Add the method**

Edit `dailywork/lib/repositories/api/api_user_repository.dart` — add this method inside the `ApiUserRepository` class (after `updateFcmToken`):

```dart
  Future<UserModel> updateDisplayName(String name) async {
    await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'display_name': name},
    );
    return getMe();
  }
```

- [ ] **Step 2: Run analyze**

```bash
cd dailywork && flutter analyze lib/repositories/api/api_user_repository.dart
```

Expected: no new issues.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/repositories/api/api_user_repository.dart
git commit -m "feat(user-repo): add updateDisplayName"
```

---

## Task 11: Widen `ApiAuthRepository.setupProfile` + `AuthNotifier`

**Files:**
- Modify: `dailywork/lib/repositories/api/api_auth_repository.dart`
- Modify: `dailywork/lib/providers/auth_provider.dart`

- [ ] **Step 1: Update `ApiAuthRepository.setupProfile`**

Open `dailywork/lib/repositories/api/api_auth_repository.dart`. Find `Future<void> setupProfile(String userType)` and replace with:

```dart
  Future<void> setupProfile(String userType, {String? displayName}) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/setup-profile',
      data: {
        'user_type': userType,
        if (displayName != null) 'display_name': displayName,
      },
    );
  }
```

- [ ] **Step 2: Update `AuthNotifier.setupProfile` + add `refreshMe`**

Open `dailywork/lib/providers/auth_provider.dart`. Replace `setupProfile` with:

```dart
  Future<void> setupProfile(String userType, {String? displayName}) async {
    await _authRepo.setupProfile(userType, displayName: displayName);
    final user = await _userRepo.getMe();
    state = AuthState(
      user: user,
      status: AuthStatus.authenticated,
      pendingRedirect: state.pendingRedirect,
    );
  }

  /// Re-fetches the current user and updates state without disturbing status
  /// or pendingRedirect. Used after profile edits (e.g. display_name change).
  Future<void> refreshMe() async {
    final user = await _userRepo.getMe();
    state = state.copyWith(user: user);
  }
```

- [ ] **Step 3: Run analyze**

```bash
cd dailywork && flutter analyze lib/repositories/api/api_auth_repository.dart lib/providers/auth_provider.dart
```

Expected: no issues. Note `RoleSelectScreen` still calls `setupProfile('worker')` with no named arg — that's fine because `displayName` is optional.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/repositories/api/api_auth_repository.dart dailywork/lib/providers/auth_provider.dart
git commit -m "feat(auth-provider): widen setupProfile with displayName; add refreshMe"
```

---

## Task 12: Create `ApiReviewRepository` + provider

**Files:**
- Create: `dailywork/lib/repositories/api/api_review_repository.dart`

- [ ] **Step 1: Create the file**

Create `dailywork/lib/repositories/api/api_review_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String reviewerDisplayName;

  const Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.reviewerDisplayName,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewerDisplayName: (json['reviewer_display_name'] as String?) ?? '',
      );
}

class ReviewPage {
  final List<Review> items;
  final int total;
  final int limit;
  final int offset;

  const ReviewPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
        items: (json['items'] as List<dynamic>)
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        limit: json['limit'] as int,
        offset: json['offset'] as int,
      );
}

class ApiReviewRepository {
  final Dio _dio;
  ApiReviewRepository(this._dio);

  Future<ReviewPage> getUserReviews(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/$userId/reviews',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ReviewPage.fromJson(res.data!);
  }
}

final apiReviewRepositoryProvider = Provider<ApiReviewRepository>((ref) {
  return ApiReviewRepository(ref.watch(apiClientProvider));
});

final userReviewsProvider =
    FutureProvider.family<ReviewPage, String>((ref, userId) async {
  return ref.watch(apiReviewRepositoryProvider).getUserReviews(userId);
});
```

- [ ] **Step 2: Run analyze**

```bash
cd dailywork && flutter analyze lib/repositories/api/api_review_repository.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/repositories/api/api_review_repository.dart
git commit -m "feat(review-repo): add ApiReviewRepository + userReviewsProvider for paginated review list"
```

---

## Task 13: Create `NameEntryScreen` + register route

**Files:**
- Create: `dailywork/lib/screens/auth/name_entry_screen.dart`
- Modify: `dailywork/lib/core/router/app_router.dart`

- [ ] **Step 1: Inspect the existing router file**

```bash
cat dailywork/lib/core/router/app_router.dart
```

Note the pattern used for route declarations (e.g., `GoRoute(path: ..., builder: ...)` vs. `ShellRoute`, vs. any `Extra` argument patterns). Match the same style in Step 3.

- [ ] **Step 2: Create the screen**

Create `dailywork/lib/screens/auth/name_entry_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/repositories/api/api_user_repository.dart';

enum NameEntryMode { onboardingWorker, edit }

class NameEntryArgs {
  final NameEntryMode mode;
  final String? initialName;
  const NameEntryArgs({required this.mode, this.initialName});
}

class NameEntryScreen extends ConsumerStatefulWidget {
  final NameEntryArgs args;
  const NameEntryScreen({super.key, required this.args});

  @override
  ConsumerState<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends ConsumerState<NameEntryScreen> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.args.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.args.mode == NameEntryMode.onboardingWorker) {
        await ref
            .read(authProvider.notifier)
            .setupProfile('worker', displayName: trimmed);
        if (!mounted) return;
        context.go('/worker/home');
      } else {
        await ref.read(apiUserRepositoryProvider).updateDisplayName(trimmed);
        await ref.read(authProvider.notifier).refreshMe();
        if (!mounted) return;
        context.pop();
      }
    } catch (e) {
      final apiError = ApiException.extract(e);
      if (mounted) {
        setState(() {
          _error = apiError?.message ?? 'Could not save. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnboarding = widget.args.mode == NameEntryMode.onboardingWorker;
    final heading = isOnboarding ? 'What should I call you?' : 'Edit your name';

    return Scaffold(
      appBar: isOnboarding
          ? null
          : AppBar(
              backgroundColor: AppTheme.primary,
              title: const Text('Edit name',
                  style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                heading,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                maxLength: 60,
                enabled: !_loading,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _isValid ? _submit() : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Your name',
                ),
                style: GoogleFonts.nunito(fontSize: 18),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isValid && !_loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.nunito(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Register the route**

Open `dailywork/lib/core/router/app_router.dart`. Add an import at the top:

```dart
import 'package:dailywork/screens/auth/name_entry_screen.dart';
```

Inside the route list (alongside existing top-level `GoRoute` entries like role-select), add:

```dart
GoRoute(
  path: '/name-entry',
  builder: (context, state) {
    final args = state.extra as NameEntryArgs;
    return NameEntryScreen(args: args);
  },
),
```

If the file uses a `const` list of routes, convert to non-const as needed. If it uses a different routing pattern (e.g., a `routes` getter), follow that pattern with the same `builder` body.

- [ ] **Step 4: Run analyze**

```bash
cd dailywork && flutter analyze lib/screens/auth/name_entry_screen.dart lib/core/router/app_router.dart
```

Expected: no new issues.

- [ ] **Step 5: Commit**

```bash
git add dailywork/lib/screens/auth/name_entry_screen.dart dailywork/lib/core/router/app_router.dart
git commit -m "feat(auth): add NameEntryScreen (onboarding + edit modes) and /name-entry route"
```

---

## Task 14: Worker role-select routes through name entry

**Files:**
- Modify: `dailywork/lib/screens/auth/role_select_screen.dart`

- [ ] **Step 1: Update the worker branch**

Open `dailywork/lib/screens/auth/role_select_screen.dart`. Add the import:

```dart
import 'package:dailywork/screens/auth/name_entry_screen.dart';
```

Replace the `_select` method with:

```dart
  Future<void> _select(String userType) async {
    if (userType == 'worker') {
      // New workers must set a display name before proceeding.
      context.push('/name-entry',
          extra: const NameEntryArgs(mode: NameEntryMode.onboardingWorker));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).setupProfile(userType);
      if (!mounted) return;
      context.go('/employer/home');
    } catch (e) {
      final apiError = ApiException.extract(e);
      if (mounted) {
        setState(() {
          _error = apiError?.message ?? 'Something went wrong. Please try again.';
          _loading = false;
        });
      }
    }
  }
```

- [ ] **Step 2: Run analyze**

```bash
cd dailywork && flutter analyze lib/screens/auth/role_select_screen.dart
```

Expected: no new issues.

- [ ] **Step 3: Smoke-check manually (optional but recommended)**

Run the app and walk through: fresh user OTP → role-select → tap Worker → lands on `/name-entry`. Name required to proceed. Employer branch still goes straight to home. If you can't run the app, skip.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/screens/auth/role_select_screen.dart
git commit -m "feat(onboarding): route new workers through NameEntryScreen before setup-profile"
```

---

## Task 15: Update `WorkerProfileScreen`

**Files:**
- Modify: `dailywork/lib/screens/worker/worker_profile_screen.dart`

- [ ] **Step 1: Replace the full file**

Replace the full contents of `dailywork/lib/screens/worker/worker_profile_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/repositories/api/api_review_repository.dart';
import 'package:dailywork/screens/auth/name_entry_screen.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          strings['profile'] ?? 'Profile',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [LanguageToggleButton()],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _ProfileHeader(
                  displayName: user.displayName,
                  ratingAvg: user.workerProfile?.ratingAvg ?? 0,
                  jobsCompleted: user.workerProfile?.jobsCompleted ?? 0,
                  totalReviews: user.workerProfile?.totalReviews ?? 0,
                  strings: strings,
                  onEditName: () => context.push(
                    '/name-entry',
                    extra: NameEntryArgs(
                      mode: NameEntryMode.edit,
                      initialName: user.displayName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Skills section
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings['core_skills'] ?? 'Core Skills',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (user.workerProfile?.skills ?? [])
                              .map(
                                (skill) => Chip(
                                  label: Text(skill),
                                  backgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  labelStyle: GoogleFonts.nunito(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide.none,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stats section — Reviews + Jobs Done (Reliability dropped)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatRow(
                          label: strings['reviews'] ?? 'Reviews',
                          value: '${user.workerProfile?.totalReviews ?? 0}',
                        ),
                        const Divider(height: 20),
                        _StatRow(
                          label: strings['jobs_completed'] ?? 'Jobs Done',
                          value: '${user.workerProfile?.jobsCompleted ?? 0}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Reviews section — live from backend
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings['recent_reviews'] ?? 'Recent Reviews',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ReviewsList(userId: user.id),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  const _ReviewsList({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPage = ref.watch(userReviewsProvider(userId));

    return asyncPage.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\u2019t load reviews',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(userReviewsProvider(userId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return Text(
            'No reviews yet',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
          );
        }
        return Column(
          children: page.items
              .asMap()
              .entries
              .map((entry) => _ReviewItem(
                    review: entry.value,
                    isLast: entry.key == page.items.length - 1,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.ratingAvg,
    required this.jobsCompleted,
    required this.totalReviews,
    required this.strings,
    required this.onEditName,
  });

  final String displayName;
  final double ratingAvg;
  final int jobsCompleted;
  final int totalReviews;
  final Map<String, String> strings;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final firstLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.accent,
            child: Text(
              firstLetter,
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                onPressed: onEditName,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              strings['worker'] ?? 'Worker',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeaderStat(
                value: ratingAvg.toStringAsFixed(1),
                label: '\u2605 Rating',
              ),
              _HeaderStat(
                value: '$jobsCompleted',
                label: strings['jobs_completed'] ?? 'Jobs Done',
              ),
              _HeaderStat(
                value: '$totalReviews',
                label: strings['reviews'] ?? 'Reviews',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review, required this.isLast});
  final Review review;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy-MM-dd').format(review.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.reviewerDisplayName,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateLabel,
                style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
          if (!isLast) const Divider(height: 16),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
cd dailywork && flutter analyze lib/screens/worker/worker_profile_screen.dart
```

Expected: no issues. If `intl` isn't already in `pubspec.yaml`, check CLAUDE.md — it's listed as a key package. If missing, add it to `pubspec.yaml` dependencies and run `flutter pub get`.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/worker/worker_profile_screen.dart
git commit -m "feat(worker-profile): drop Reliability row, swap Experience→Reviews, live reviews list, edit-name icon"
```

---

## Task 16: Update `EmployerProfileScreen`

**Files:**
- Modify: `dailywork/lib/screens/employer/employer_profile_screen.dart`

- [ ] **Step 1: Replace the hardcoded job count**

Open `dailywork/lib/screens/employer/employer_profile_screen.dart`. Find the line:

```dart
'12 jobs posted',
```

Replace with:

```dart
'${user.employerProfile?.jobsPosted ?? 0} jobs posted',
```

No edit-name icon is added — employers display `business_name`, not `display_name`, so editing `display_name` would be invisible (see spec decision).

- [ ] **Step 2: Run analyze**

```bash
cd dailywork && flutter analyze lib/screens/employer/employer_profile_screen.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/employer/employer_profile_screen.dart
git commit -m "feat(employer-profile): show real jobs_posted count (no edit-name icon)"
```

---

## Task 17: Delete `mock_users.dart`

**Files:**
- Delete: `dailywork/lib/repositories/mock_users.dart`

- [ ] **Step 1: Verify no remaining references**

```bash
cd dailywork && grep -r 'mock_users' lib/ test/
```

Expected: no matches. If any match is found, fix those imports/usages before deleting — running the deletion with live references will break the build.

- [ ] **Step 2: Delete the file**

```bash
rm dailywork/lib/repositories/mock_users.dart
```

- [ ] **Step 3: Run analyze + tests**

```bash
cd dailywork && flutter analyze && flutter test
```

Expected: clean analyze, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A dailywork/lib/repositories/mock_users.dart
git commit -m "chore: delete mock_users.dart — all consumers now use DB-backed data"
```

---

## Task 18: Full-stack regression pass

**Files:** none modified — verification only.

- [ ] **Step 1: Backend — run full test suite**

```bash
cd backend && pytest -v
```

Expected: all tests pass. If any pre-existing tests fail due to the new required fields, they need fixing (those would be tests that hardcoded response bodies).

- [ ] **Step 2: Flutter — run full test suite + analyze**

```bash
cd dailywork && flutter analyze && flutter test
```

Expected: both clean.

- [ ] **Step 3: Manual smoke (if possible)**

Bring up the stack (`uvicorn` + `flutter run`) and walk through:

1. **New worker signup:** OTP → role-select → tap Worker → `/name-entry` screen shows "What should I call you?". Try Continue with empty field — button disabled. Enter a name → Continue → lands on worker home. Open profile → name + avatar initial match entered value. Jobs Done = 0. Reviews = 0. "No reviews yet".
2. **Edit name:** from worker profile, tap the pencil icon next to name → edit screen with current name pre-filled. Change it → Continue → pops back, header updates.
3. **Existing user (simulate via DB):** set a user's `display_name` to NULL in Supabase. Log in as them → profile header shows phone number as the name. Tap edit, set a real name. Header updates.
4. **Employer:** fresh employer signup → lands on employer home without any name-entry screen. Profile screen shows business_name as the displayed name, no pencil icon, "0 jobs posted". Post a job. Refresh profile — count increments.
5. **Worker reviews with data:** seed a few reviews in Supabase for a worker. Open worker profile as that worker — reviews list shows them with star rating, reviewer's display_name (or phone fallback), comment, date.

- [ ] **Step 4: If all green, final commit (empty or doc-only)**

If nothing else changed, skip. Otherwise:

```bash
git commit --allow-empty -m "chore: verify full-stack regression after mock-user removal"
```

---

## Self-Review Notes

Spec coverage check:

- [x] `display_name` column + nullable + 60-char cap → Task 1
- [x] `UserResponse`/`UserUpdate` schema updates → Task 2
- [x] `WorkerProfileResponse.jobs_completed` → Task 3 (schema) + Task 5 (compute)
- [x] `EmployerProfileResponse.jobs_posted` → Task 4 (schema) + Task 6 (compute)
- [x] `POST /auth/setup-profile` accepts `display_name` → Task 7
- [x] Paginated `GET /users/{id}/reviews` → Task 8
- [x] `UserModel` refactor (drop reliability/experience, add jobsCompleted/jobsPosted, displayName precedence) → Task 9
- [x] `updateDisplayName` on user repo → Task 10
- [x] Widened `setupProfile` + new `refreshMe` → Task 11
- [x] `ApiReviewRepository` + provider → Task 12
- [x] `NameEntryScreen` (onboarding + edit) + route → Task 13
- [x] RoleSelect worker branch routes through name entry → Task 14
- [x] `WorkerProfileScreen` — drop Reliability row, Experience → Reviews, edit-name icon, live reviews → Task 15
- [x] `EmployerProfileScreen` — real `jobs_posted`, no edit icon → Task 16
- [x] `mock_users.dart` deleted → Task 17
- [x] Regression pass → Task 18
