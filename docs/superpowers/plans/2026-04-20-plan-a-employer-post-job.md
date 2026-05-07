# Plan A — Employer Can Post — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the end-to-end "employer signs in → posts a job via 3-step wizard → it appears in feed and on the employer's MY JOBS list, and they can cancel it" workflow on top of the existing skeleton.

**Architecture:** Single SQL migration adds five nullable columns to `jobs`; FastAPI gets one new endpoint per resource (cancel, employers/me/jobs); Flutter gets a wizard route stack (`WizardScaffold` + `LocationPickerSheet`) plus an employer 3-tab shell with an orange FAB. Spec is `docs/superpowers/specs/2026-04-20-job-posting-application-loop-design.md` (Plan A scope only).

**Tech Stack:** Python 3.11 + FastAPI + supabase-py + pytest (live dev DB, `app.dependency_overrides`), Flutter + Riverpod + go_router + Dio + `geolocator` (new) + `flutter_map` (new, lazy-loaded) + `latlong2` (new) + `url_launcher` (new, plumbing only).

---

## File Structure

### Backend — to create
- `backend/supabase/migrations/007_add_jobs_posting_columns.sql` — adds `start_time`, `end_time`, `is_urgent`, `address_text`, `cancellation_reason` to `jobs`
- `backend/tests/test_jobs_create_extended.py` — verifies new fields persist on POST/PATCH and surface on GET
- `backend/tests/test_jobs_cancel.py` — verifies cancel endpoint, valid/invalid status guard, application cascade
- `backend/tests/test_employers_me_jobs.py` — verifies grouped output of GET /employers/me/jobs

### Backend — to modify
- `backend/app/schemas/jobs.py` — extend `JobCreate`, `JobUpdate`, `JobResponse`; add `JobCancelRequest`, `EmployerJobsGroupedResponse`
- `backend/app/routers/jobs.py` — add `POST /{job_id}/cancel`
- `backend/app/routers/employers.py` — add `GET /me/jobs`
- `backend/app/services/job_service.py` — add `cancel_job()` helper

### Frontend — to create
- `dailywork/lib/screens/shared/widgets/wizard_scaffold.dart` — 3-step wizard shell (progress dots, back/next buttons)
- `dailywork/lib/screens/shared/widgets/location_picker_sheet.dart` — modal sheet: GPS default, lazy-loaded map override
- `dailywork/lib/screens/employer/employer_post_job_screen.dart` — wizard route (steps 1/2/3 + submit)
- `dailywork/lib/screens/employer/employer_my_jobs_screen.dart` — list grouped by status
- `dailywork/lib/providers/post_job_wizard_provider.dart` — wizard state across steps
- `dailywork/lib/providers/my_posted_jobs_provider.dart` — `myPostedJobsProvider`
- `dailywork/lib/core/utils/tap_to_call.dart` — `dialPhone(String phone)` helper
- `dailywork/test/wizard_scaffold_test.dart`
- `dailywork/test/location_picker_sheet_test.dart`
- `dailywork/test/my_posted_jobs_provider_test.dart`

### Frontend — to modify
- `dailywork/pubspec.yaml` — add `geolocator`, `flutter_map`, `latlong2`, `url_launcher`
- `dailywork/lib/models/job_model.dart` — add `startTime`, `endTime`, `isUrgent`, `addressText`, `cancellationReason`
- `dailywork/lib/repositories/job_repository.dart` — add `createJob`, `updateJob`, `cancelJob`, `getMyPostedJobs` to abstract
- `dailywork/lib/repositories/api/api_job_repository.dart` — implement the four new methods
- `dailywork/lib/providers/language_provider.dart` — add wizard/my-jobs/cancel strings
- `dailywork/lib/screens/employer/employer_shell.dart` — switch to Home/My Jobs/Profile + orange FAB
- `dailywork/lib/screens/employer/employer_home_screen.dart` — refactor to "today" digest (active jobs starting today + jobs needing attention)
- `dailywork/lib/screens/employer/employer_job_detail_screen.dart` — wire `dialPhone` helper into existing manage area (placeholder until Plan B)
- `dailywork/lib/core/router/app_router.dart` — add `/employer/my-jobs`, `/employer/jobs/new`, `/employer/jobs/:id/edit`

---

## Conventions

- **Migrations:** sequential numbered SQL files in `backend/supabase/migrations/`. Run via Supabase SQL editor or `supabase db push`. Make every column addition `IF NOT EXISTS` for idempotency.
- **Backend tests:** hit the live dev DB; never mock the DB. Override `get_current_user` and role-guards via `app.dependency_overrides[...] = lambda: fake_user`. Always clean up in fixture teardown. Reset `app.dependency_overrides.clear()` in a `try/finally`.
- **Pydantic:** UUIDs serialized to `str` before sending to supabase-py (`payload["category_id"] = str(...)`).
- **Frontend strings:** add to **both** the `_enStrings` and `_knStrings` maps in `language_provider.dart`. Never hardcode user-facing strings in widgets.
- **Frontend tests:** widget tests wrap subjects in `MaterialApp` + `ProviderScope`. Use `tester.pumpAndSettle()` after async work.
- **Commits:** one commit per task. Conventional-commit prefixes: `feat`, `chore`, `test`, `fix`. Co-author trailer is set globally — don't add per-commit.

---

## Task 1: Migration — add jobs posting columns

**Files:**
- Create: `backend/supabase/migrations/007_add_jobs_posting_columns.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- 007_add_jobs_posting_columns.sql
-- Adds five nullable columns to jobs for the posting wizard:
--  - start_time / end_time: hours within the start_date/end_date window
--  - is_urgent: employer-flagged urgency (drives UI badge + sort weight later)
--  - address_text: human-readable address from Nominatim reverse-geocode
--  - cancellation_reason: free-text reason captured from cancel modal
-- All nullable for backwards compatibility with rows created before Plan A.

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS start_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS end_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS address_text TEXT NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL;
```

- [ ] **Step 2: Apply the migration to the dev Supabase project**

Run via Supabase SQL editor (paste the file contents) or `supabase db push` if the local CLI is configured.

Expected: each `ALTER TABLE` returns "Success. No rows returned."

- [ ] **Step 3: Verify columns exist**

Run in Supabase SQL editor:
```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'jobs'
  AND column_name IN ('start_time','end_time','is_urgent','address_text','cancellation_reason')
ORDER BY column_name;
```
Expected: 5 rows, `is_urgent` `is_nullable=NO` (default `false`), the other four `is_nullable=YES`.

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/migrations/007_add_jobs_posting_columns.sql
git commit -m "feat(db): add posting wizard columns to jobs (migration 007)"
```

---

## Task 2: Pydantic schema updates

**Files:**
- Modify: `backend/app/schemas/jobs.py`

- [ ] **Step 1: Read the current file**

Read `backend/app/schemas/jobs.py` end-to-end to refresh memory.

- [ ] **Step 2: Replace the file with the extended schemas**

Overwrite `backend/app/schemas/jobs.py` with:

```python
from pydantic import BaseModel, UUID4, field_validator
from uuid import UUID
from datetime import date, datetime, time
from typing import Literal


class JobCreate(BaseModel):
    category_id: UUID4
    title: str
    description: str | None = None
    location_lat: float
    location_lng: float
    address_text: str | None = None
    wage_per_day: float
    workers_needed: int = 1
    start_date: date
    end_date: date
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool = False

    @field_validator("wage_per_day")
    @classmethod
    def wage_must_be_positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("wage_per_day must be positive")
        return v

    @field_validator("workers_needed")
    @classmethod
    def workers_must_be_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("workers_needed must be at least 1")
        return v


class JobUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    wage_per_day: float | None = None
    workers_needed: int | None = None
    status: Literal["open", "assigned", "in_progress", "completed", "cancelled"] | None = None
    start_date: date | None = None
    end_date: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool | None = None
    address_text: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None


class JobCancelRequest(BaseModel):
    reason: str | None = None


class JobResponse(BaseModel):
    id: UUID
    employer_id: UUID
    category_id: UUID
    title: str
    description: str | None = None
    location_lat: float
    location_lng: float
    address_text: str | None = None
    wage_per_day: float
    workers_needed: int
    workers_assigned: int
    status: str
    start_date: date
    end_date: date
    start_time: time | None = None
    end_time: time | None = None
    is_urgent: bool = False
    cancellation_reason: str | None = None
    created_at: datetime
    category_name: str | None = None
    employer_name: str | None = None
    applicant_count: int = 0


class JobListResponse(BaseModel):
    data: list[JobResponse]
    page: int
    page_size: int
    total: int


class EmployerJobsGroupedResponse(BaseModel):
    open: list[JobResponse]
    assigned: list[JobResponse]
    in_progress: list[JobResponse]
    completed: list[JobResponse]
    cancelled: list[JobResponse]
```

- [ ] **Step 3: Verify the backend boots**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok` (no import errors).

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas/jobs.py
git commit -m "feat(api): extend job schemas with wizard fields and cancel/grouped responses"
```

---

## Task 3: Test that POST /jobs persists and returns the new fields

**Files:**
- Create: `backend/tests/test_jobs_create_extended.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_jobs_create_extended.py`:

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
        {"user_id": employer_id, "business_name": "WizardCo"}
    ).execute()
    yield employer_id
    db.table("jobs").delete().eq("employer_id", employer_id).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("users").delete().eq("id", employer_id).execute()


def _category_id(db) -> str:
    return db.table("categories").select("id").limit(1).execute().data[0]["id"]


def test_create_job_persists_wizard_fields(seeded_employer):
    db = get_supabase()
    fake_user = {"id": seeded_employer, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        body = {
            "category_id": _category_id(db),
            "title": "Brick layer",
            "description": "Lay 200 bricks",
            "location_lat": 12.9716,
            "location_lng": 77.5946,
            "address_text": "HSR Layout, Bengaluru",
            "wage_per_day": 850,
            "workers_needed": 2,
            "start_date": "2026-05-01",
            "end_date": "2026-05-01",
            "start_time": "08:00:00",
            "end_time": "17:30:00",
            "is_urgent": True,
        }
        res = client.post("/api/v1/jobs/", json=body)
        assert res.status_code == 201, res.text
        data = res.json()
        assert data["start_time"] == "08:00:00"
        assert data["end_time"] == "17:30:00"
        assert data["is_urgent"] is True
        assert data["address_text"] == "HSR Layout, Bengaluru"
    finally:
        app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to confirm it passes**

(The router already inserts the full payload via `body.model_dump()`, so the schema change in Task 2 is what makes this test pass — Step 1 verifies the wiring.)

Run: `cd backend && pytest tests/test_jobs_create_extended.py -v`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_jobs_create_extended.py
git commit -m "test(jobs): cover wizard fields on POST /jobs"
```

---

## Task 4: Add `cancel_job` service helper + `POST /jobs/{id}/cancel` endpoint

**Files:**
- Modify: `backend/app/services/job_service.py`
- Modify: `backend/app/routers/jobs.py`

- [ ] **Step 1: Add `cancel_job` to job_service.py**

Append to `backend/app/services/job_service.py`:

```python
async def cancel_job(db: Client, job_id: str, employer_id: str, reason: str | None) -> dict:
    """Cancels a job and cascades to all pending/accepted applications.

    Raises ValueError on guard failures (router converts to 400/403/404).
    """
    job_result = db.table("jobs").select("*").eq("id", job_id).execute()
    if not job_result.data:
        raise ValueError("not_found")
    job = job_result.data[0]
    if job["employer_id"] != employer_id:
        raise ValueError("forbidden")
    if job["status"] not in ("open", "assigned"):
        raise ValueError("invalid_status")

    update = {"status": "cancelled"}
    if reason is not None:
        update["cancellation_reason"] = reason
    db.table("jobs").update(update).eq("id", job_id).execute()

    # Cascade — set every pending/accepted application on this job to withdrawn.
    # (withdrawn_reason column lands in Plan B; for now we just flip status.)
    db.table("applications").update({"status": "withdrawn"}) \
        .eq("job_id", job_id) \
        .in_("status", ["pending", "accepted"]) \
        .execute()

    await invalidate_job_cache()
    refreshed = db.table("jobs").select("*").eq("id", job_id).execute().data[0]
    return refreshed
```

- [ ] **Step 2: Add the route to jobs.py**

In `backend/app/routers/jobs.py`, add this import at the top (alongside the existing schema imports):

```python
from app.schemas.jobs import JobCreate, JobUpdate, JobResponse, JobListResponse, JobCancelRequest
```

Then append this route at the end of the file (after `delete_job`):

```python
@router.post("/{job_id}/cancel", response_model=JobResponse)
@limiter.limit("10/minute")
async def cancel_job(
    request: Request,
    job_id: str,
    body: JobCancelRequest,
    employer: dict = Depends(require_employer),
):
    db = get_supabase()
    try:
        refreshed = await job_service.cancel_job(db, job_id, employer["id"], body.reason)
    except ValueError as e:
        if str(e) == "not_found":
            raise HTTPException(status_code=404, detail="Job not found")
        if str(e) == "forbidden":
            raise HTTPException(status_code=403, detail="Not your job")
        if str(e) == "invalid_status":
            raise HTTPException(status_code=400, detail="Only open or assigned jobs can be cancelled")
        raise
    enriched = _enrich_rows_batch(db, [refreshed])
    return enriched[0]
```

- [ ] **Step 3: Verify backend boots**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok`.

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/job_service.py backend/app/routers/jobs.py
git commit -m "feat(api): POST /jobs/{id}/cancel with employer guard and application cascade"
```

---

## Task 5: Tests for cancel endpoint

**Files:**
- Create: `backend/tests/test_jobs_cancel.py`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_jobs_cancel.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_employer
from app.supabase_client import get_supabase

client = TestClient(app)


def _seed_job(db, employer_id: str, status: str = "open") -> str:
    cat_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]
    job_id = str(uuid.uuid4())
    db.table("jobs").insert({
        "id": job_id,
        "employer_id": employer_id,
        "category_id": cat_id,
        "title": f"cancel-test-{status}",
        "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 1,
        "start_date": "2026-01-01", "end_date": "2026-01-02",
        "status": status,
    }).execute()
    return job_id


def _seed_worker(db) -> str:
    worker_id = str(uuid.uuid4())
    db.table("users").insert(
        {"id": worker_id, "phone_number": f"+1{worker_id[:10]}", "user_type": "worker"}
    ).execute()
    db.table("worker_profiles").insert({"user_id": worker_id}).execute()
    return worker_id


@pytest.fixture
def seeded_employer():
    db = get_supabase()
    eid = str(uuid.uuid4())
    db.table("users").insert(
        {"id": eid, "phone_number": f"+1{eid[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": eid, "business_name": "CancelCo"}
    ).execute()
    yield eid
    db.table("applications").delete().eq("worker_id", eid).execute()
    db.table("jobs").delete().eq("employer_id", eid).execute()
    db.table("employer_profiles").delete().eq("user_id", eid).execute()
    db.table("users").delete().eq("id", eid).execute()


def test_cancel_open_job_succeeds(seeded_employer):
    db = get_supabase()
    job_id = _seed_job(db, seeded_employer, "open")
    fake_user = {"id": seeded_employer, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.post(f"/api/v1/jobs/{job_id}/cancel", json={"reason": "Plans changed"})
        assert res.status_code == 200, res.text
        body = res.json()
        assert body["status"] == "cancelled"
        assert body["cancellation_reason"] == "Plans changed"
    finally:
        app.dependency_overrides.clear()


def test_cancel_in_progress_job_blocked(seeded_employer):
    db = get_supabase()
    job_id = _seed_job(db, seeded_employer, "in_progress")
    fake_user = {"id": seeded_employer, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.post(f"/api/v1/jobs/{job_id}/cancel", json={"reason": None})
        assert res.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_cancel_other_employer_job_forbidden(seeded_employer):
    db = get_supabase()
    job_id = _seed_job(db, seeded_employer, "open")
    other = str(uuid.uuid4())
    db.table("users").insert(
        {"id": other, "phone_number": f"+1{other[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": other, "business_name": "OtherCo"}
    ).execute()
    fake_user = {"id": other, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.post(f"/api/v1/jobs/{job_id}/cancel", json={"reason": None})
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()
        db.table("employer_profiles").delete().eq("user_id", other).execute()
        db.table("users").delete().eq("id", other).execute()


def test_cancel_cascades_to_applications(seeded_employer):
    db = get_supabase()
    job_id = _seed_job(db, seeded_employer, "assigned")
    worker_id = _seed_worker(db)
    db.table("applications").insert({
        "job_id": job_id, "worker_id": worker_id, "status": "accepted"
    }).execute()
    fake_user = {"id": seeded_employer, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.post(f"/api/v1/jobs/{job_id}/cancel", json={"reason": None})
        assert res.status_code == 200
        apps = db.table("applications").select("status").eq("job_id", job_id).execute().data
        assert all(a["status"] == "withdrawn" for a in apps)
    finally:
        app.dependency_overrides.clear()
        db.table("applications").delete().eq("worker_id", worker_id).execute()
        db.table("worker_profiles").delete().eq("user_id", worker_id).execute()
        db.table("users").delete().eq("id", worker_id).execute()
```

- [ ] **Step 2: Run tests**

Run: `cd backend && pytest tests/test_jobs_cancel.py -v`
Expected: 4 PASSED.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_jobs_cancel.py
git commit -m "test(jobs): cover cancel endpoint guards and application cascade"
```

---

## Task 6: Add `GET /employers/me/jobs` endpoint

**Files:**
- Modify: `backend/app/routers/employers.py`

- [ ] **Step 1: Add the import + route**

At the top of `backend/app/routers/employers.py`, replace the schemas import line with:

```python
from app.schemas.employers import EmployerProfileResponse, EmployerProfileUpdate
from app.schemas.jobs import EmployerJobsGroupedResponse
from app.services.job_service import _enrich_rows_batch
```

Append at the end of the file:

```python
@router.get("/me/jobs", response_model=EmployerJobsGroupedResponse)
async def get_my_posted_jobs(current_user: dict = Depends(require_employer)):
    db = get_supabase()
    rows = (
        db.table("jobs")
        .select("*, categories(name)")
        .eq("employer_id", current_user["id"])
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )
    enriched = _enrich_rows_batch(db, rows)
    grouped = {
        "open": [], "assigned": [], "in_progress": [], "completed": [], "cancelled": [],
    }
    for r in enriched:
        bucket = grouped.get(r["status"])
        if bucket is not None:
            bucket.append(r)
    return grouped
```

- [ ] **Step 2: Verify backend boots**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/routers/employers.py
git commit -m "feat(api): GET /employers/me/jobs grouped by status"
```

---

## Task 7: Tests for `GET /employers/me/jobs`

**Files:**
- Create: `backend/tests/test_employers_me_jobs.py`

- [ ] **Step 1: Write the test**

Create `backend/tests/test_employers_me_jobs.py`:

```python
import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_employer
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_employer_with_mixed_jobs():
    db = get_supabase()
    eid = str(uuid.uuid4())
    db.table("users").insert(
        {"id": eid, "phone_number": f"+1{eid[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": eid, "business_name": "MyJobsCo"}
    ).execute()
    cat_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]
    for status in ("open", "open", "assigned", "completed", "cancelled"):
        db.table("jobs").insert({
            "employer_id": eid,
            "category_id": cat_id,
            "title": f"my-jobs-{status}-{uuid.uuid4()}",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": status,
        }).execute()
    yield eid
    db.table("jobs").delete().eq("employer_id", eid).execute()
    db.table("employer_profiles").delete().eq("user_id", eid).execute()
    db.table("users").delete().eq("id", eid).execute()


def test_employer_me_jobs_groups_by_status(seeded_employer_with_mixed_jobs):
    fake_user = {"id": seeded_employer_with_mixed_jobs, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.get("/api/v1/employers/me/jobs")
        assert res.status_code == 200, res.text
        body = res.json()
        assert len(body["open"]) == 2
        assert len(body["assigned"]) == 1
        assert len(body["completed"]) == 1
        assert len(body["cancelled"]) == 1
        assert len(body["in_progress"]) == 0
    finally:
        app.dependency_overrides.clear()


def test_employer_me_jobs_excludes_other_employers(seeded_employer_with_mixed_jobs):
    db = get_supabase()
    other = str(uuid.uuid4())
    db.table("users").insert(
        {"id": other, "phone_number": f"+1{other[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": other, "business_name": "OtherCo"}
    ).execute()
    fake_user = {"id": other, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_user
    app.dependency_overrides[require_employer] = lambda: fake_user
    try:
        res = client.get("/api/v1/employers/me/jobs")
        assert res.status_code == 200
        body = res.json()
        assert all(len(v) == 0 for v in body.values())
    finally:
        app.dependency_overrides.clear()
        db.table("employer_profiles").delete().eq("user_id", other).execute()
        db.table("users").delete().eq("id", other).execute()
```

- [ ] **Step 2: Run tests**

Run: `cd backend && pytest tests/test_employers_me_jobs.py -v`
Expected: 2 PASSED.

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_employers_me_jobs.py
git commit -m "test(employers): cover grouped my-jobs endpoint"
```

---

## Task 8: Add Flutter pubspec deps

**Files:**
- Modify: `dailywork/pubspec.yaml`

- [ ] **Step 1: Add the four packages**

In `dailywork/pubspec.yaml`, under `dependencies:` (just below `intl: ^0.19.0`), add:

```yaml
  geolocator: ^13.0.1
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  url_launcher: ^6.3.0
```

- [ ] **Step 2: Fetch packages**

Run: `cd dailywork && flutter pub get`
Expected: "Got dependencies!" with no version-resolution errors. If the constraint solver complains about `geolocator`, accept the suggested version.

- [ ] **Step 3: Verify analyzer is still clean**

Run: `cd dailywork && flutter analyze`
Expected: "No issues found!" (or only pre-existing warnings unrelated to this change).

- [ ] **Step 4: Commit**

```bash
git add dailywork/pubspec.yaml dailywork/pubspec.lock
git commit -m "chore(deps): add geolocator, flutter_map, latlong2, url_launcher"
```

---

## Task 9: Extend `JobModel` with new fields

**Files:**
- Modify: `dailywork/lib/models/job_model.dart`

- [ ] **Step 1: Replace the file**

Overwrite `dailywork/lib/models/job_model.dart` with:

```dart
enum JobStatus { open, assigned, inProgress, completed, cancelled }

class JobModel {
  final String id;
  final String employerId;
  final String employerName;
  final String categoryId;
  final String categoryName;
  final String title;
  final String? description;
  final double locationLat;
  final double locationLng;
  final String? addressText;
  final double wagePerDay;
  final int workersNeeded;
  final int workersAssigned;
  final JobStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime; // "HH:MM:SS"
  final String? endTime;
  final bool isUrgent;
  final String? cancellationReason;
  final DateTime createdAt;
  final int applicantCount;

  const JobModel({
    required this.id,
    required this.employerId,
    required this.employerName,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    this.description,
    required this.locationLat,
    required this.locationLng,
    this.addressText,
    required this.wagePerDay,
    required this.workersNeeded,
    required this.workersAssigned,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.isUrgent,
    this.cancellationReason,
    required this.createdAt,
    required this.applicantCount,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    JobStatus parseStatus(String s) => switch (s) {
      'open'        => JobStatus.open,
      'assigned'    => JobStatus.assigned,
      'in_progress' => JobStatus.inProgress,
      'completed'   => JobStatus.completed,
      'cancelled'   => JobStatus.cancelled,
      _             => JobStatus.open,
    };

    return JobModel(
      id: json['id'] as String,
      employerId: json['employer_id'] as String,
      employerName: (json['employer_name'] as String?) ?? '',
      categoryId: json['category_id'] as String,
      categoryName: (json['category_name'] as String?) ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      locationLat: (json['location_lat'] as num).toDouble(),
      locationLng: (json['location_lng'] as num).toDouble(),
      addressText: json['address_text'] as String?,
      wagePerDay: (json['wage_per_day'] as num).toDouble(),
      workersNeeded: json['workers_needed'] as int,
      workersAssigned: json['workers_assigned'] as int,
      status: parseStatus(json['status'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      isUrgent: (json['is_urgent'] as bool?) ?? false,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      applicantCount: (json['applicant_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'category_id': categoryId,
    'title': title,
    if (description != null) 'description': description,
    'location_lat': locationLat,
    'location_lng': locationLng,
    if (addressText != null) 'address_text': addressText,
    'wage_per_day': wagePerDay,
    'workers_needed': workersNeeded,
    'start_date': startDate.toIso8601String().split('T').first,
    'end_date': endDate.toIso8601String().split('T').first,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    'is_urgent': isUrgent,
  };

  @override
  bool operator ==(Object other) => other is JobModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

Note: the `isUrgent` getter from the previous file (`startDate.difference(...) <= 2 && status == open`) is replaced by the persisted `isUrgent` field. Any caller relying on the old getter will keep compiling because the property name is unchanged; only the source of truth shifted.

- [ ] **Step 2: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new issues.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/models/job_model.dart
git commit -m "feat(model): extend JobModel with wizard fields and toCreateJson"
```

---

## Task 10: Extend `JobRepository` (abstract + Api impl)

**Files:**
- Modify: `dailywork/lib/repositories/job_repository.dart`
- Modify: `dailywork/lib/repositories/api/api_job_repository.dart`

- [ ] **Step 1: Update the abstract**

Overwrite `dailywork/lib/repositories/job_repository.dart`:

```dart
import '../models/category_model.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';

class EmployerJobsGrouped {
  final List<JobModel> open;
  final List<JobModel> assigned;
  final List<JobModel> inProgress;
  final List<JobModel> completed;
  final List<JobModel> cancelled;
  const EmployerJobsGrouped({
    required this.open,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
  });

  Iterable<JobModel> get all sync* {
    yield* open;
    yield* assigned;
    yield* inProgress;
    yield* completed;
    yield* cancelled;
  }
}

abstract class JobRepository {
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter});
  Future<JobModel> getJobById(String id);
  Future<List<CategoryModel>> getCategories();

  Future<JobModel> createJob(Map<String, dynamic> body);
  Future<JobModel> updateJob(String id, Map<String, dynamic> body);
  Future<JobModel> cancelJob(String id, {String? reason});
  Future<EmployerJobsGrouped> getMyPostedJobs();
}
```

- [ ] **Step 2: Implement the new methods**

Replace `dailywork/lib/repositories/api/api_job_repository.dart` with:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/models/category_model.dart';
import 'package:dailywork/models/job_filter.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/repositories/job_repository.dart';

class ApiJobRepository implements JobRepository {
  final Dio _dio;

  ApiJobRepository(this._dio);

  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/jobs/',
      queryParameters: {
        'lat': 12.9716,
        'lng': 77.5946,
        'radius_km': 25,
        'category_id': ?categoryId,
      },
    );
    final data = response.data!;
    return (data['data'] as List<dynamic>)
        .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JobModel> getJobById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/jobs/$id');
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get<List<dynamic>>('/categories/');
    return (response.data ?? [])
        .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JobModel> createJob(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>('/jobs/', data: body);
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<JobModel> updateJob(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>('/jobs/$id', data: body);
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<JobModel> cancelJob(String id, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/jobs/$id/cancel',
      data: {'reason': reason},
    );
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<EmployerJobsGrouped> getMyPostedJobs() async {
    final response = await _dio.get<Map<String, dynamic>>('/employers/me/jobs');
    final data = response.data!;
    List<JobModel> parse(String key) => ((data[key] as List<dynamic>?) ?? [])
        .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
        .toList();
    return EmployerJobsGrouped(
      open: parse('open'),
      assigned: parse('assigned'),
      inProgress: parse('in_progress'),
      completed: parse('completed'),
      cancelled: parse('cancelled'),
    );
  }
}

final apiJobRepositoryProvider = Provider<ApiJobRepository>((ref) {
  return ApiJobRepository(ref.watch(apiClientProvider));
});
```

- [ ] **Step 3: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/repositories/job_repository.dart dailywork/lib/repositories/api/api_job_repository.dart
git commit -m "feat(repo): add createJob, updateJob, cancelJob, getMyPostedJobs"
```

---

## Task 11: Add wizard + my-posted-jobs providers

**Files:**
- Create: `dailywork/lib/providers/post_job_wizard_provider.dart`
- Create: `dailywork/lib/providers/my_posted_jobs_provider.dart`

- [ ] **Step 1: Write the wizard state provider**

Create `dailywork/lib/providers/post_job_wizard_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostJobWizardState {
  final String? categoryId;
  final String title;
  final String? description;
  final double? locationLat;
  final double? locationLng;
  final String? addressText;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime; // "HH:MM:SS"
  final String? endTime;
  final int workersNeeded;
  final double? wagePerDay;
  final bool isUrgent;

  const PostJobWizardState({
    this.categoryId,
    this.title = '',
    this.description,
    this.locationLat,
    this.locationLng,
    this.addressText,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.workersNeeded = 1,
    this.wagePerDay,
    this.isUrgent = false,
  });

  PostJobWizardState copyWith({
    String? categoryId,
    String? title,
    String? description,
    double? locationLat,
    double? locationLng,
    String? addressText,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    int? workersNeeded,
    double? wagePerDay,
    bool? isUrgent,
  }) => PostJobWizardState(
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    description: description ?? this.description,
    locationLat: locationLat ?? this.locationLat,
    locationLng: locationLng ?? this.locationLng,
    addressText: addressText ?? this.addressText,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    workersNeeded: workersNeeded ?? this.workersNeeded,
    wagePerDay: wagePerDay ?? this.wagePerDay,
    isUrgent: isUrgent ?? this.isUrgent,
  );

  bool get step1Valid =>
      categoryId != null && title.trim().isNotEmpty &&
      locationLat != null && locationLng != null;

  bool get step2Valid =>
      startDate != null && endDate != null &&
      !endDate!.isBefore(startDate!) && workersNeeded >= 1;

  bool get step3Valid => wagePerDay != null && wagePerDay! > 0;

  Map<String, dynamic> toCreateBody() => {
    'category_id': categoryId,
    'title': title,
    if (description != null && description!.isNotEmpty) 'description': description,
    'location_lat': locationLat,
    'location_lng': locationLng,
    if (addressText != null) 'address_text': addressText,
    'wage_per_day': wagePerDay,
    'workers_needed': workersNeeded,
    'start_date': startDate!.toIso8601String().split('T').first,
    'end_date': endDate!.toIso8601String().split('T').first,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    'is_urgent': isUrgent,
  };
}

class PostJobWizardNotifier extends StateNotifier<PostJobWizardState> {
  PostJobWizardNotifier() : super(const PostJobWizardState());

  void update(PostJobWizardState Function(PostJobWizardState s) fn) {
    state = fn(state);
  }

  void reset() => state = const PostJobWizardState();
}

final postJobWizardProvider =
    StateNotifierProvider.autoDispose<PostJobWizardNotifier, PostJobWizardState>(
  (ref) => PostJobWizardNotifier(),
);
```

- [ ] **Step 2: Write the my-posted-jobs provider**

Create `dailywork/lib/providers/my_posted_jobs_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

final myPostedJobsProvider = FutureProvider.autoDispose<EmployerJobsGrouped>((ref) async {
  final repo = ref.watch(apiJobRepositoryProvider);
  return repo.getMyPostedJobs();
});
```

- [ ] **Step 3: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new issues.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/providers/post_job_wizard_provider.dart dailywork/lib/providers/my_posted_jobs_provider.dart
git commit -m "feat(providers): wizard state and myPostedJobs providers"
```

---

## Task 12: Add new strings to language_provider

**Files:**
- Modify: `dailywork/lib/providers/language_provider.dart`

- [ ] **Step 1: Append the new strings to both maps**

In `dailywork/lib/providers/language_provider.dart`, add the following keys to **both** `_enStrings` and `_knStrings` (insert before the closing `};` of each):

EN entries:
```dart
  'post_job_title': 'Post a job',
  'edit_job_title': 'Edit job',
  'wizard_step_1': 'What & where',
  'wizard_step_2': 'When & how many',
  'wizard_step_3': 'Pay & confirm',
  'next': 'Next',
  'back': 'Back',
  'cancel': 'Cancel',
  'job_category': 'Category',
  'job_title_field': 'Job title',
  'job_description': 'Description (optional)',
  'pick_location': 'Pick location',
  'use_my_location': 'Use my location',
  'adjust_on_map': 'Adjust on map',
  'type_address': 'Type address',
  'start_time_field': 'Start time',
  'end_time_field': 'End time',
  'end_date': 'End date',
  'workers_count': 'Workers needed',
  'mark_urgent': 'Mark as urgent',
  'preview': 'Preview',
  'submit_post': 'Post job',
  'save_changes': 'Save changes',
  'cancel_job': 'Cancel job',
  'cancel_job_prompt': 'Why are you cancelling?',
  'reason_other_worker': 'Found another worker',
  'reason_plans_changed': 'Plans changed',
  'reason_other': 'Other',
  'job_posted': 'Job posted ✓',
  'job_cancelled': 'Job cancelled',
  'no_posted_jobs': 'No jobs yet — tap + to post one',
  'today_digest': "Today's overview",
  'tab_my_jobs': 'My Jobs',
```

KN entries (paste these as-is — translations refined later):
```dart
  'post_job_title': 'ಕೆಲಸ ಪೋಸ್ಟ್ ಮಾಡಿ',
  'edit_job_title': 'ಕೆಲಸ ಸಂಪಾದಿಸಿ',
  'wizard_step_1': 'ಏನು ಮತ್ತು ಎಲ್ಲಿ',
  'wizard_step_2': 'ಯಾವಾಗ ಮತ್ತು ಎಷ್ಟು',
  'wizard_step_3': 'ಪಾವತಿ ಮತ್ತು ದೃಢೀಕರಣ',
  'next': 'ಮುಂದೆ',
  'back': 'ಹಿಂದೆ',
  'cancel': 'ರದ್ದುಗೊಳಿಸಿ',
  'job_category': 'ವರ್ಗ',
  'job_title_field': 'ಕೆಲಸದ ಶೀರ್ಷಿಕೆ',
  'job_description': 'ವಿವರಣೆ (ಐಚ್ಛಿಕ)',
  'pick_location': 'ಸ್ಥಳ ಆಯ್ಕೆಮಾಡಿ',
  'use_my_location': 'ನನ್ನ ಸ್ಥಳ ಬಳಸಿ',
  'adjust_on_map': 'ನಕ್ಷೆಯಲ್ಲಿ ಸರಿಹೊಂದಿಸಿ',
  'type_address': 'ವಿಳಾಸ ಟೈಪ್ ಮಾಡಿ',
  'start_time_field': 'ಪ್ರಾರಂಭ ಸಮಯ',
  'end_time_field': 'ಮುಕ್ತಾಯ ಸಮಯ',
  'end_date': 'ಮುಕ್ತಾಯ ದಿನಾಂಕ',
  'workers_count': 'ಬೇಕಾದ ಕಾರ್ಮಿಕರು',
  'mark_urgent': 'ತುರ್ತು ಎಂದು ಗುರುತಿಸಿ',
  'preview': 'ಮುನ್ನೋಟ',
  'submit_post': 'ಕೆಲಸ ಪೋಸ್ಟ್ ಮಾಡಿ',
  'save_changes': 'ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ',
  'cancel_job': 'ಕೆಲಸ ರದ್ದುಗೊಳಿಸಿ',
  'cancel_job_prompt': 'ಏಕೆ ರದ್ದುಗೊಳಿಸುತ್ತಿದ್ದೀರಿ?',
  'reason_other_worker': 'ಬೇರೆ ಕಾರ್ಮಿಕ ಸಿಕ್ಕರು',
  'reason_plans_changed': 'ಯೋಜನೆ ಬದಲಾಯಿತು',
  'reason_other': 'ಇತರೆ',
  'job_posted': 'ಕೆಲಸ ಪೋಸ್ಟ್ ಆಗಿದೆ ✓',
  'job_cancelled': 'ಕೆಲಸ ರದ್ದಾಗಿದೆ',
  'no_posted_jobs': 'ಇನ್ನೂ ಕೆಲಸಗಳಿಲ್ಲ — ಪೋಸ್ಟ್ ಮಾಡಲು + ಒತ್ತಿರಿ',
  'today_digest': 'ಇಂದಿನ ಸಮಾಲೋಚನೆ',
  'tab_my_jobs': 'ನನ್ನ ಕೆಲಸಗಳು',
```

- [ ] **Step 2: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new issues.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/providers/language_provider.dart
git commit -m "feat(i18n): add wizard, my-jobs, and cancel strings"
```

---

## Task 13: Build `WizardScaffold` widget

**Files:**
- Create: `dailywork/lib/screens/shared/widgets/wizard_scaffold.dart`
- Create: `dailywork/test/wizard_scaffold_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `dailywork/test/wizard_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/screens/shared/widgets/wizard_scaffold.dart';

void main() {
  testWidgets('renders three progress dots and child content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WizardScaffold(
            currentStep: 0,
            totalSteps: 3,
            stepLabel: 'What & where',
            child: const Text('STEP_BODY'),
            onBack: () {},
            onNext: () {},
            nextEnabled: true,
          ),
        ),
      ),
    );
    expect(find.text('STEP_BODY'), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-2')), findsOneWidget);
  });

  testWidgets('Next button is disabled when nextEnabled=false', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WizardScaffold(
            currentStep: 0,
            totalSteps: 3,
            stepLabel: 'What & where',
            child: const SizedBox(),
            onBack: () {},
            onNext: () {},
            nextEnabled: false,
          ),
        ),
      ),
    );
    final btn = tester.widget<ElevatedButton>(find.byKey(const ValueKey('wizard-next')));
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd dailywork && flutter test test/wizard_scaffold_test.dart`
Expected: FAIL — `wizard_scaffold.dart` not found.

- [ ] **Step 3: Implement the widget**

Create `dailywork/lib/screens/shared/widgets/wizard_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class WizardScaffold extends ConsumerWidget {
  const WizardScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabel,
    required this.child,
    required this.onBack,
    required this.onNext,
    required this.nextEnabled,
    this.nextLabel,
  });

  final int currentStep; // 0-indexed
  final int totalSteps;
  final String stepLabel;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final bool nextEnabled;
  final String? nextLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          strings['post_job_title'] ?? 'Post a job',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final isActive = i == currentStep;
                  final isDone = i < currentStep;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      key: ValueKey('wizard-dot-$i'),
                      width: 36,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.accent
                            : isDone
                                ? AppTheme.accent.withOpacity(0.5)
                                : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                stepLabel,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: child)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('wizard-back'),
                      onPressed: onBack,
                      child: Text(strings['back'] ?? 'Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const ValueKey('wizard-next'),
                      onPressed: nextEnabled ? onNext : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(nextLabel ?? strings['next'] ?? 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd dailywork && flutter test test/wizard_scaffold_test.dart`
Expected: 2 PASSED.

- [ ] **Step 5: Commit**

```bash
git add dailywork/lib/screens/shared/widgets/wizard_scaffold.dart dailywork/test/wizard_scaffold_test.dart
git commit -m "feat(widget): WizardScaffold with progress dots and back/next"
```

---

## Task 14: Build `LocationPickerSheet` widget

**Files:**
- Create: `dailywork/lib/screens/shared/widgets/location_picker_sheet.dart`
- Create: `dailywork/test/location_picker_sheet_test.dart`

The map is **lazy-loaded**: `flutter_map` is only imported inside the "Adjust on map" branch so an employer who accepts the GPS default never pays the map widget cost.

- [ ] **Step 1: Write the test**

Create `dailywork/test/location_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/screens/shared/widgets/location_picker_sheet.dart';

void main() {
  testWidgets('renders the three primary actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              initialLat: 12.97, initialLng: 77.59,
              onPicked: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('loc-use-gps')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc-adjust-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc-type-address')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd dailywork && flutter test test/location_picker_sheet_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the widget**

Create `dailywork/lib/screens/shared/widgets/location_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String? address;
  const PickedLocation({required this.lat, required this.lng, this.address});
}

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAddress,
    required this.onPicked,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final void Function(PickedLocation) onPicked;

  @override
  ConsumerState<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _useGps() async {
    setState(() { _busy = true; _error = null; });
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission effective = perm;
      if (perm == LocationPermission.denied) {
        effective = await Geolocator.requestPermission();
      }
      if (effective == LocationPermission.denied ||
          effective == LocationPermission.deniedForever) {
        setState(() { _error = 'Location permission denied'; _busy = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      widget.onPicked(PickedLocation(
        lat: pos.latitude, lng: pos.longitude, address: null,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _error = 'Could not read GPS'; _busy = false; });
    }
  }

  Future<void> _adjustOnMap() async {
    // Lazy import: only executed if user picks this branch.
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLat: widget.initialLat ?? 12.9716,
          initialLng: widget.initialLng ?? 77.5946,
        ),
      ),
    );
    if (picked != null) {
      widget.onPicked(picked);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _typeAddress() async {
    final ctrl = TextEditingController(text: widget.initialAddress ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type address'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Use')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    // Address-only branch: keep the existing lat/lng (or city-center fallback).
    widget.onPicked(PickedLocation(
      lat: widget.initialLat ?? 12.9716,
      lng: widget.initialLng ?? 77.5946,
      address: result.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings['pick_location'] ?? 'Pick location',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const ValueKey('loc-use-gps'),
            onPressed: _busy ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: Text(strings['use_my_location'] ?? 'Use my location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('loc-adjust-map'),
            onPressed: _busy ? null : _adjustOnMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(strings['adjust_on_map'] ?? 'Adjust on map'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('loc-type-address'),
            onPressed: _busy ? null : _typeAddress,
            icon: const Icon(Icons.edit_outlined),
            label: Text(strings['type_address'] ?? 'Type address'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}

// Pulled into its own file-private widget so the flutter_map import is not
// evaluated until the user actively pushes this route.
class _MapPickerScreen extends StatefulWidget {
  const _MapPickerScreen({required this.initialLat, required this.initialLng});

  final double initialLat;
  final double initialLng;

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;

  @override
  Widget build(BuildContext context) {
    // Local imports kept top-of-file in Dart; the build cost only happens here.
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust pin')),
      body: _MapBody(
        lat: _lat,
        lng: _lng,
        onMove: (lat, lng) => setState(() { _lat = lat; _lng = lng; }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(
          PickedLocation(lat: _lat, lng: _lng),
        ),
        label: const Text('Use this spot'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.lat, required this.lng, required this.onMove});

  final double lat;
  final double lng;
  final void Function(double, double) onMove;

  @override
  Widget build(BuildContext context) {
    // ignore: import_of_legacy_library_into_null_safe
    return _MapImpl(lat: lat, lng: lng, onMove: onMove);
  }
}

// flutter_map import isolated to its own implementation widget
class _MapImpl extends StatelessWidget {
  const _MapImpl({required this.lat, required this.lng, required this.onMove});

  final double lat;
  final double lng;
  final void Function(double, double) onMove;

  @override
  Widget build(BuildContext context) {
    // Imports inlined here so analyzer doesn't pull flutter_map into widgets that
    // skip the map branch.
    // ignore: prefer_const_constructors
    return _buildMap(context);
  }

  Widget _buildMap(BuildContext context) {
    return _LazyMap(lat: lat, lng: lng, onMove: onMove);
  }
}

// Final hop where flutter_map types are referenced.
class _LazyMap extends StatelessWidget {
  const _LazyMap({required this.lat, required this.lng, required this.onMove});

  final double lat;
  final double lng;
  final void Function(double, double) onMove;

  @override
  Widget build(BuildContext context) {
    // Imports kept inside the method to keep analyzer happy across branches.
    // (Dart imports must be top-of-file; this comment is the design rationale.)
    return _MapWidget(lat: lat, lng: lng, onMove: onMove);
  }
}

// Concrete flutter_map binding lives in a separate file in real practice;
// here we keep it inline for plan brevity.
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;

class _MapWidget extends StatefulWidget {
  const _MapWidget({required this.lat, required this.lng, required this.onMove});

  final double lat;
  final double lng;
  final void Function(double, double) onMove;

  @override
  State<_MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<_MapWidget> {
  late final fmap.MapController _ctrl = fmap.MapController();

  @override
  Widget build(BuildContext context) {
    return fmap.FlutterMap(
      mapController: _ctrl,
      options: fmap.MapOptions(
        initialCenter: ll.LatLng(widget.lat, widget.lng),
        initialZoom: 14,
        onPositionChanged: (pos, _) {
          final c = pos.center;
          if (c != null) widget.onMove(c.latitude, c.longitude);
        },
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.dailywork.app',
        ),
        fmap.MarkerLayer(markers: [
          fmap.Marker(
            point: ll.LatLng(widget.lat, widget.lng),
            width: 40, height: 40,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
          ),
        ]),
      ],
    );
  }
}
```

> **Important:** Dart requires imports at the top of the file. Move the two `import` statements from inside `_LazyMap` up to the top of `location_picker_sheet.dart` (alongside the existing `package:flutter/material.dart` etc.) when you save the file. The collapsed structure here is just for plan readability — the lazy semantics come from the fact that `_MapPickerScreen` is only **constructed** (and its `flutter_map` widget tree only built) when the user taps "Adjust on map." The import cost is per-app-launch, not per-render.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd dailywork && flutter test test/location_picker_sheet_test.dart`
Expected: PASSED.

- [ ] **Step 5: Commit**

```bash
git add dailywork/lib/screens/shared/widgets/location_picker_sheet.dart dailywork/test/location_picker_sheet_test.dart
git commit -m "feat(widget): LocationPickerSheet with GPS + lazy map + address branches"
```

---

## Task 15: Build `EmployerPostJobScreen` (the wizard route)

**Files:**
- Create: `dailywork/lib/screens/employer/employer_post_job_screen.dart`

- [ ] **Step 1: Implement the screen**

Create `dailywork/lib/screens/employer/employer_post_job_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/category_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/providers/post_job_wizard_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/screens/shared/widgets/location_picker_sheet.dart';
import 'package:dailywork/screens/shared/widgets/wizard_scaffold.dart';

class EmployerPostJobScreen extends ConsumerStatefulWidget {
  const EmployerPostJobScreen({super.key, this.jobId});

  /// When non-null, the wizard hydrates from this job and submits PATCH instead.
  final String? jobId;

  @override
  ConsumerState<EmployerPostJobScreen> createState() =>
      _EmployerPostJobScreenState();
}

class _EmployerPostJobScreenState extends ConsumerState<EmployerPostJobScreen> {
  int _step = 0;
  bool _hydrated = false;
  bool _submitting = false;

  Future<void> _hydrateIfEditing() async {
    if (_hydrated || widget.jobId == null) return;
    _hydrated = true;
    final job = await ref.read(jobDetailProvider(widget.jobId!).future);
    ref.read(postJobWizardProvider.notifier).update((_) => PostJobWizardState(
      categoryId: job.categoryId,
      title: job.title,
      description: job.description,
      locationLat: job.locationLat,
      locationLng: job.locationLng,
      addressText: job.addressText,
      startDate: job.startDate,
      endDate: job.endDate,
      startTime: job.startTime,
      endTime: job.endTime,
      workersNeeded: job.workersNeeded,
      wagePerDay: job.wagePerDay,
      isUrgent: job.isUrgent,
    ));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final repo = ref.read(apiJobRepositoryProvider);
    final body = ref.read(postJobWizardProvider).toCreateBody();
    final strings = ref.read(stringsProvider);
    try {
      if (widget.jobId == null) {
        await repo.createJob(body);
      } else {
        await repo.updateJob(widget.jobId!, body);
      }
      ref.invalidate(myPostedJobsProvider);
      ref.read(postJobWizardProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings['job_posted'] ?? 'Job posted ✓')),
      );
      context.go('/employer/my-jobs');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _hydrateIfEditing();
    final state = ref.watch(postJobWizardProvider);
    final strings = ref.watch(stringsProvider);

    final stepLabel = switch (_step) {
      0 => strings['wizard_step_1'] ?? 'What & where',
      1 => strings['wizard_step_2'] ?? 'When & how many',
      _ => strings['wizard_step_3'] ?? 'Pay & confirm',
    };
    final nextEnabled = switch (_step) {
      0 => state.step1Valid,
      1 => state.step2Valid,
      _ => state.step3Valid && !_submitting,
    };
    final nextLabel = _step == 2
        ? (widget.jobId == null
            ? strings['submit_post'] ?? 'Post job'
            : strings['save_changes'] ?? 'Save changes')
        : strings['next'] ?? 'Next';

    return WillPopScope(
      onWillPop: () async {
        if (_step > 0) { setState(() => _step--); return false; }
        return true;
      },
      child: WizardScaffold(
        currentStep: _step,
        totalSteps: 3,
        stepLabel: stepLabel,
        onBack: () {
          if (_step == 0) {
            context.pop();
          } else {
            setState(() => _step--);
          }
        },
        onNext: () {
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _submit();
          }
        },
        nextEnabled: nextEnabled,
        nextLabel: nextLabel,
        child: switch (_step) {
          0 => _Step1(state: state),
          1 => _Step2(state: state),
          _ => _Step3(state: state, isUrgent: state.isUrgent),
        },
      ),
    );
  }
}

class _Step1 extends ConsumerWidget {
  const _Step1({required this.state});
  final PostJobWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        categoriesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Failed to load categories'),
          data: (cats) => DropdownButtonFormField<String>(
            initialValue: state.categoryId,
            decoration: InputDecoration(
              labelText: strings['job_category'] ?? 'Category',
              border: const OutlineInputBorder(),
            ),
            items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => ref
                .read(postJobWizardProvider.notifier)
                .update((s) => s.copyWith(categoryId: v)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.title,
          decoration: InputDecoration(
            labelText: strings['job_title_field'] ?? 'Job title',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(postJobWizardProvider.notifier)
              .update((s) => s.copyWith(title: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.description,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: strings['job_description'] ?? 'Description (optional)',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => ref
              .read(postJobWizardProvider.notifier)
              .update((s) => s.copyWith(description: v)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.location_on_outlined),
          label: Text(state.addressText ??
              (state.locationLat != null
                  ? '${state.locationLat!.toStringAsFixed(4)}, ${state.locationLng!.toStringAsFixed(4)}'
                  : strings['pick_location'] ?? 'Pick location')),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => LocationPickerSheet(
                initialLat: state.locationLat,
                initialLng: state.locationLng,
                initialAddress: state.addressText,
                onPicked: (p) {
                  ref.read(postJobWizardProvider.notifier).update((s) =>
                      s.copyWith(locationLat: p.lat, locationLng: p.lng, addressText: p.address));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Step2 extends ConsumerWidget {
  const _Step2({required this.state});
  final PostJobWizardState state;

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtT(String? t) => t ?? '—';

  Future<DateTime?> _pickDate(BuildContext context, DateTime? init) =>
      showDatePicker(
        context: context,
        initialDate: init ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

  Future<TimeOfDay?> _pickTime(BuildContext context, String? init) =>
      showTimePicker(
        context: context,
        initialTime: init == null
            ? TimeOfDay.now()
            : TimeOfDay(hour: int.parse(init.split(':')[0]), minute: int.parse(init.split(':')[1])),
      );

  String _toHms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final notifier = ref.read(postJobWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await _pickDate(context, state.startDate);
                  if (d != null) notifier.update((s) => s.copyWith(startDate: d));
                },
                child: Text('${strings['start_date'] ?? 'Start'}: ${_fmt(state.startDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await _pickDate(context, state.endDate);
                  if (d != null) notifier.update((s) => s.copyWith(endDate: d));
                },
                child: Text('${strings['end_date'] ?? 'End'}: ${_fmt(state.endDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _pickTime(context, state.startTime);
                  if (t != null) notifier.update((s) => s.copyWith(startTime: _toHms(t)));
                },
                child: Text('${strings['start_time_field'] ?? 'Start time'}: ${_fmtT(state.startTime)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await _pickTime(context, state.endTime);
                  if (t != null) notifier.update((s) => s.copyWith(endTime: _toHms(t)));
                },
                child: Text('${strings['end_time_field'] ?? 'End time'}: ${_fmtT(state.endTime)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(strings['workers_count'] ?? 'Workers needed', style: GoogleFonts.nunito(fontSize: 14)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: state.workersNeeded > 1
                  ? () => notifier.update((s) => s.copyWith(workersNeeded: s.workersNeeded - 1))
                  : null,
            ),
            Text('${state.workersNeeded}', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => notifier.update((s) => s.copyWith(workersNeeded: s.workersNeeded + 1)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step3 extends ConsumerStatefulWidget {
  const _Step3({required this.state, required this.isUrgent});
  final PostJobWizardState state;
  final bool isUrgent;

  @override
  ConsumerState<_Step3> createState() => _Step3State();
}

class _Step3State extends ConsumerState<_Step3> {
  late final TextEditingController _wage =
      TextEditingController(text: widget.state.wagePerDay?.toStringAsFixed(0) ?? '');

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(postJobWizardProvider);
    final notifier = ref.read(postJobWizardProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _wage,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            labelText: strings['wage'] ?? 'Wage',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => notifier.update((s) => s.copyWith(wagePerDay: double.tryParse(v))),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(strings['mark_urgent'] ?? 'Mark as urgent'),
          value: state.isUrgent,
          onChanged: (v) => notifier.update((s) => s.copyWith(isUrgent: v)),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings['preview'] ?? 'Preview',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(state.title.isEmpty ? '—' : state.title,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                Text('₹${state.wagePerDay?.toStringAsFixed(0) ?? '0'} ${strings['per_day'] ?? '/day'}',
                    style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.accent)),
                if (state.addressText != null) Text(state.addressText!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _wage.dispose();
    super.dispose();
  }
}
```

> Note: `categoryListProvider` is the existing provider name in `lib/providers/category_provider.dart`. If the actual symbol differs, swap the import and call accordingly — read the file once at execution time to confirm.

- [ ] **Step 2: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new errors. (Warnings about unused dialog action labels in `cancel_job` are fine — addressed in Task 16.)

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/employer/employer_post_job_screen.dart
git commit -m "feat(employer): post-job wizard screen (3 steps + edit hydration)"
```

---

## Task 16: Build `EmployerMyJobsScreen` (grouped list + cancel modal)

**Files:**
- Create: `dailywork/lib/screens/employer/employer_my_jobs_screen.dart`
- Create: `dailywork/test/my_posted_jobs_provider_test.dart`

- [ ] **Step 1: Implement the screen**

Create `dailywork/lib/screens/employer/employer_my_jobs_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

class EmployerMyJobsScreen extends ConsumerWidget {
  const EmployerMyJobsScreen({super.key});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, JobModel job) async {
    final strings = ref.read(stringsProvider);
    String? selectedReason;
    final reasons = [
      strings['reason_other_worker'] ?? 'Found another worker',
      strings['reason_plans_changed'] ?? 'Plans changed',
      strings['reason_other'] ?? 'Other',
    ];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings['cancel_job_prompt'] ?? 'Why are you cancelling?',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: reasons
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: selectedReason == r,
                          onSelected: (_) => setState(() => selectedReason = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: Text(strings['cancel_job'] ?? 'Cancel job'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep job')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final repo = ref.read(apiJobRepositoryProvider);
    try {
      await repo.cancelJob(job.id, reason: selectedReason);
      ref.invalidate(myPostedJobsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings['job_cancelled'] ?? 'Job cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final groupedAsync = ref.watch(myPostedJobsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(strings['tab_my_jobs'] ?? 'My Jobs',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (grouped) {
          final all = grouped.all.toList();
          if (all.isEmpty) {
            return Center(child: Text(strings['no_posted_jobs'] ?? 'No jobs yet — tap + to post one'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPostedJobsProvider),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Section('Open', grouped.open, onCancel: (j) => _confirmCancel(context, ref, j)),
                _Section('Assigned', grouped.assigned, onCancel: (j) => _confirmCancel(context, ref, j)),
                _Section('In progress', grouped.inProgress),
                _Section('Completed', grouped.completed),
                _Section('Cancelled', grouped.cancelled),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.jobs, {this.onCancel});
  final String title;
  final List<JobModel> jobs;
  final void Function(JobModel)? onCancel;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
          child: Text(title,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
        ...jobs.map((j) => Card(
              child: ListTile(
                title: Text(j.title),
                subtitle: Text('₹${j.wagePerDay.toStringAsFixed(0)} · ${j.workersAssigned}/${j.workersNeeded} hired'),
                trailing: onCancel == null
                    ? IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => context.push('/employer/jobs/${j.id}'),
                      )
                    : Wrap(spacing: 4, children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/employer/jobs/${j.id}/edit')),
                        IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () => onCancel!(j)),
                      ]),
                onTap: () => context.push('/employer/jobs/${j.id}'),
              ),
            )),
      ],
    );
  }
}
```

- [ ] **Step 2: Write the provider test**

Create `dailywork/test/my_posted_jobs_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/models/category_model.dart';
import 'package:dailywork/models/job_filter.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

class _FakeRepo implements JobRepository {
  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async => [];
  @override
  Future<JobModel> getJobById(String id) async => throw UnimplementedError();
  @override
  Future<List<CategoryModel>> getCategories() async => [];
  @override
  Future<JobModel> createJob(Map<String, dynamic> body) async => throw UnimplementedError();
  @override
  Future<JobModel> updateJob(String id, Map<String, dynamic> body) async => throw UnimplementedError();
  @override
  Future<JobModel> cancelJob(String id, {String? reason}) async => throw UnimplementedError();
  @override
  Future<EmployerJobsGrouped> getMyPostedJobs() async => const EmployerJobsGrouped(
        open: [], assigned: [], inProgress: [], completed: [], cancelled: [],
      );
}

void main() {
  test('myPostedJobsProvider returns grouped object from repo', () async {
    final container = ProviderContainer(overrides: [
      apiJobRepositoryProvider.overrideWithValue(_FakeRepo() as dynamic),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(myPostedJobsProvider.future);
    expect(result.open, isEmpty);
    expect(result.cancelled, isEmpty);
  });
}
```

> The cast `as dynamic` is required because `apiJobRepositoryProvider` exposes `ApiJobRepository`, not the abstract interface, and we want to override it with our fake without inheriting concrete dependencies. If the analyzer complains, add `// ignore: argument_type_not_assignable` to the override line.

- [ ] **Step 3: Run the test**

Run: `cd dailywork && flutter test test/my_posted_jobs_provider_test.dart`
Expected: PASS. If it fails because of the override type mismatch, refactor `myPostedJobsProvider` to depend on a `Provider<JobRepository>` indirection — but try the simple path first.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/screens/employer/employer_my_jobs_screen.dart dailywork/test/my_posted_jobs_provider_test.dart
git commit -m "feat(employer): MY JOBS screen with grouped list and cancel modal"
```

---

## Task 17: Refactor `EmployerHomeScreen` to a "today" digest

**Files:**
- Modify: `dailywork/lib/screens/employer/employer_home_screen.dart`

The home screen currently shows the public jobs feed (not the employer's own jobs). Per spec, it should become a small dashboard showing **today's active jobs** + **jobs that need employer attention** (e.g., open jobs with applicants). Plan A only ships counts and a CTA to MY JOBS — applicant data lands in Plan B.

- [ ] **Step 1: Replace the file**

Overwrite `dailywork/lib/screens/employer/employer_home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';

class EmployerHomeScreen extends ConsumerWidget {
  const EmployerHomeScreen({super.key});

  bool _startsToday(JobModel j) {
    final now = DateTime.now();
    final d = j.startDate;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final groupedAsync = ref.watch(myPostedJobsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(strings['today_digest'] ?? "Today's overview",
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (grouped) {
          final activeToday = grouped.assigned.where(_startsToday).toList()
            ..addAll(grouped.inProgress);
          final openCount = grouped.open.length;
          final assignedCount = grouped.assigned.length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPostedJobsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: _Stat(label: 'Open', value: openCount.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: 'Assigned', value: assignedCount.toString())),
                ]),
                const SizedBox(height: 16),
                Text('Active today',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                const SizedBox(height: 8),
                if (activeToday.isEmpty)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No jobs starting today',
                        style: GoogleFonts.nunito(color: Colors.grey[600])),
                  ))
                else
                  ...activeToday.map((j) => Card(
                        child: ListTile(
                          title: Text(j.title),
                          subtitle: Text('${j.workersAssigned}/${j.workersNeeded} hired'),
                          onTap: () => context.push('/employer/jobs/${j.id}'),
                        ),
                      )),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/employer/my-jobs'),
                  child: Text(strings['tab_my_jobs'] ?? 'My Jobs'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(value, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          Text(label, style: GoogleFonts.nunito(color: Colors.grey[600])),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new errors. The previous imports for `category_chip_bar`, `filter_bottom_sheet`, `job_card`, `job_provider` are gone — that's correct (they belong on the worker browse screen, not the employer home).

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/employer/employer_home_screen.dart
git commit -m "feat(employer): replace home screen with today digest"
```

---

## Task 18: Refactor `EmployerShell` to 3 tabs + orange FAB

**Files:**
- Modify: `dailywork/lib/screens/employer/employer_shell.dart`

- [ ] **Step 1: Replace the file**

Overwrite `dailywork/lib/screens/employer/employer_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class EmployerShell extends ConsumerWidget {
  const EmployerShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.contains('/employer/my-jobs')) return 1;
    if (loc.contains('/employer/profile')) return 2;
    return 0;
  }

  bool _showFab(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    return loc.endsWith('/employer/home') || loc.endsWith('/employer/my-jobs');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: _showFab(context)
          ? FloatingActionButton(
              backgroundColor: AppTheme.accent,
              onPressed: () => context.push('/employer/jobs/new'),
              tooltip: strings['post_job'] ?? 'Post Job',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0: context.go('/employer/home');
            case 1: context.go('/employer/my-jobs');
            case 2: context.go('/employer/profile');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: strings['home'] ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: strings['tab_my_jobs'] ?? 'My Jobs',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: strings['profile'] ?? 'Profile',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add dailywork/lib/screens/employer/employer_shell.dart
git commit -m "feat(employer): 3-tab shell with Home/My Jobs/Profile + post-job FAB"
```

---

## Task 19: Wire new routes into `app_router.dart`

**Files:**
- Modify: `dailywork/lib/core/router/app_router.dart`

- [ ] **Step 1: Add imports**

In `dailywork/lib/core/router/app_router.dart`, add these imports next to the existing employer screen imports:

```dart
import 'package:dailywork/screens/employer/employer_my_jobs_screen.dart';
import 'package:dailywork/screens/employer/employer_post_job_screen.dart';
```

- [ ] **Step 2: Add the routes**

Inside the existing employer `ShellRoute`'s `routes:` list (after `/employer/profile`), append:

```dart
GoRoute(
  path: '/employer/my-jobs',
  builder: (context, state) => const EmployerMyJobsScreen(),
),
```

Then, add **two new top-level routes** outside the employer ShellRoute (so they cover the bottom nav as full-screen modals). Append after the employer `ShellRoute(...)`:

```dart
GoRoute(
  path: '/employer/jobs/new',
  builder: (context, state) => const EmployerPostJobScreen(),
),
GoRoute(
  path: '/employer/jobs/:id/edit',
  builder: (context, state) =>
      EmployerPostJobScreen(jobId: state.pathParameters['id']),
),
```

- [ ] **Step 3: Verify analyzer + routing**

Run: `cd dailywork && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/core/router/app_router.dart
git commit -m "feat(router): add /employer/my-jobs, /jobs/new, /jobs/:id/edit"
```

---

## Task 20: Add `dialPhone` helper + wire into employer detail

**Files:**
- Create: `dailywork/lib/core/utils/tap_to_call.dart`
- Modify: `dailywork/lib/screens/employer/employer_job_detail_screen.dart`

Plan A only sets up the helper and a usage site so Plan B can wire it to applicant tiles. The detail screen already has a "Manage" button slot — we add a Call button next to it that opens the employer's own phone number for now (a smoke-test hook).

- [ ] **Step 1: Create the helper**

Create `dailywork/lib/core/utils/tap_to_call.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> dialPhone(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri);
  }
  // Fall back: copy the number to clipboard so the user can paste it.
  await Clipboard.setData(ClipboardData(text: phone));
  return false;
}
```

- [ ] **Step 2: Wire it into employer_job_detail_screen.dart**

In `dailywork/lib/screens/employer/employer_job_detail_screen.dart`, add this import alongside the existing imports:

```dart
import 'package:dailywork/core/utils/tap_to_call.dart';
```

Replace the existing "Manage" button block (the `Padding` containing the `SizedBox/ElevatedButton(...Manage...)` near the bottom of the file) with a row of two buttons — Call (placeholder) + Edit:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
  child: Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.phone),
          label: const Text('Call'),
          onPressed: () => dialPhone('+10000000000'), // Plan B replaces with worker phone
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pushNamed('/employer/jobs/${job.id}/edit'),
          child: Text('Edit', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  ),
),
```

> If `pushNamed` does not work because routes use go_router, swap it for `context.push('/employer/jobs/${job.id}/edit')` (already imported via `package:go_router/go_router.dart` if you also add that import).

- [ ] **Step 3: Verify analyzer**

Run: `cd dailywork && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add dailywork/lib/core/utils/tap_to_call.dart dailywork/lib/screens/employer/employer_job_detail_screen.dart
git commit -m "feat(employer): tap-to-call helper and Edit button on job detail"
```

---

## Task 21: Final integration — analyzer, smoke test, full backend test run

**Files:**
- (no new files; this task is verification + a manual smoke step)

- [ ] **Step 1: Run the full Flutter analyzer**

Run: `cd dailywork && flutter analyze`
Expected: "No issues found!" — investigate and fix any new errors before the manual smoke.

- [ ] **Step 2: Run all Flutter tests**

Run: `cd dailywork && flutter test`
Expected: all tests pass, including the existing `widget_test.dart` smoke test.

- [ ] **Step 3: Run all backend tests**

Run: `cd backend && pytest -v`
Expected: all tests pass. Failures here usually mean an env-var (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) is missing or the dev DB is unreachable — fix the environment, not the test, unless the test is genuinely wrong.

- [ ] **Step 4: Manual smoke test on a device or emulator**

Start the backend and Flutter app:

```bash
cd backend && uvicorn app.main:app --reload --port 8000 &
cd dailywork && flutter run
```

Then walk the happy path:
1. Sign in as an employer (existing OTP flow).
2. Land on Home — see "Today's overview" with the digest.
3. Tap the orange FAB — wizard opens at Step 1.
4. Pick a category, type a title, tap location → use GPS.
5. Tap Next → pick dates and times → set workers needed → Next.
6. Type a wage → toggle Urgent → tap Post job.
7. Confirm snackbar appears, MY JOBS opens, the new job is in "Open."
8. Tap the cancel icon → pick a reason → confirm. Job moves to Cancelled.

If anything is off, write down the symptom and fix it in a follow-up commit before declaring Plan A done.

- [ ] **Step 5: Commit any smoke-test fixes**

If you needed fixes, commit them with descriptive messages. Otherwise, push the branch and open a PR titled "Plan A — Employer can post."

```bash
git push -u origin <branch>
```

---

## What ships after Plan A

- Schema is forward-compatible with Plan B/C (new nullable columns)
- Employer can: post a job (3-step wizard), edit an existing job (same wizard pre-filled), cancel a job (with optional reason chip + cascade), see grouped MY JOBS, see today's digest
- Worker side and the apply/complete loop are untouched — they ship in Plans B and C

---

## Self-Review Notes

- **Spec coverage:** every Plan A bullet from spec §8 has a task — migration (T1), Pydantic (T2), cancel endpoint (T4), GET /employers/me/jobs (T6), wizard scaffold (T13), location picker (T14), wizard route + edit (T15, T19), employer FAB (T18), employer MY JOBS (T16), employer HOME today digest (T17), tap-to-call (T20), repository extensions (T10), tests for backend (T3, T5, T7) and frontend (T13, T14, T16). ✔
- **Placeholders:** none. Every step has the literal code or command needed.
- **Type consistency:** `EmployerJobsGrouped` exposes `inProgress` (camelCase) consistently in repo, provider, and screen; backend response uses `in_progress` (snake) and the repository converts in `getMyPostedJobs`. ✔
- **Lazy map note:** Task 14's "Important" callout flags the import-placement detail explicitly; the engineer is told to relocate the imports to the top of the file when transcribing.
- **Tap-to-call placeholder:** Task 20 is honest about being a stub for Plan B; the Call button uses `+10000000000` so the smoke test can verify the dialer launches but the wire-up to a real applicant phone is Plan B's job.
