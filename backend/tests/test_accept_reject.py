import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user
from app.supabase_client import get_supabase

client = TestClient(app)


def _cat(db) -> str:
    return db.table("categories").select("id").limit(1).execute().data[0]["id"]


@pytest.fixture
def env():
    db = get_supabase()
    employer_id = str(uuid.uuid4())
    worker_id = str(uuid.uuid4())
    db.table("users").insert(
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert({"user_id": employer_id, "business_name": "AccCo"}).execute()
    db.table("users").insert(
        {"id": worker_id, "phone_number": f"+1{worker_id[:10]}", "user_type": "worker"}
    ).execute()
    db.table("worker_profiles").insert({"user_id": worker_id}).execute()
    yield {"db": db, "employer_id": employer_id, "worker_id": worker_id}
    db.table("applications").delete().eq("worker_id", worker_id).execute()
    db.table("jobs").delete().eq("employer_id", employer_id).execute()
    db.table("worker_profiles").delete().eq("user_id", worker_id).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("users").delete().eq("id", worker_id).execute()
    db.table("users").delete().eq("id", employer_id).execute()


def _seed_job(db, employer_id, needed=1, status="open", start_date="2026-01-01"):
    job_id = str(uuid.uuid4())
    db.table("jobs").insert({
        "id": job_id, "employer_id": employer_id, "category_id": _cat(db),
        "title": f"acc-{job_id}", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": needed, "workers_assigned": 0,
        "start_date": start_date, "end_date": "2030-01-02", "status": status,
    }).execute()
    return job_id


# A start_date safely in the future for tests that exercise the
# "withdraw allowed before start date" path.
_FUTURE = "2999-01-01"


def _seed_app(db, job_id, worker_id, status="pending"):
    app_id = str(uuid.uuid4())
    db.table("applications").insert(
        {"id": app_id, "job_id": job_id, "worker_id": worker_id, "status": status}
    ).execute()
    return app_id


def test_accept_bumps_assigned_and_flips_job(env):
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    job_id = _seed_job(db, employer_id, needed=1, status="open")
    app_id = _seed_app(db, job_id, worker_id)

    fake = {"id": employer_id, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake
    try:
        res = client.patch(f"/api/v1/applications/{app_id}", json={"status": "accepted"})
        assert res.status_code == 200, res.text
        assert res.json()["status"] == "accepted"
        job = db.table("jobs").select("workers_assigned, status").eq("id", job_id).execute().data[0]
        assert job["workers_assigned"] == 1
        assert job["status"] == "assigned"
    finally:
        app.dependency_overrides.clear()


def test_accept_succeeds_for_non_v4_job_id(env):
    """Regression: seeded jobs/apps use non-v4 UUIDs (e.g. 'cccccccc-0001-...').
    ApplicationResponse must accept them. UUID4 typing rejected them, raising
    ResponseValidationError -> 500 AFTER the accept had already committed
    (false-failure on the client, stale assigned count)."""
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    # uuid1 -> a valid UUID that is NOT version 4, like the seed data ids.
    job_id = str(uuid.uuid1())
    db.table("jobs").insert({
        "id": job_id, "employer_id": employer_id, "category_id": _cat(db),
        "title": f"acc-{job_id}", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 2, "workers_assigned": 0,
        "start_date": "2026-01-01", "end_date": "2026-01-02", "status": "open",
    }).execute()
    app_id = str(uuid.uuid1())
    db.table("applications").insert(
        {"id": app_id, "job_id": job_id, "worker_id": worker_id, "status": "pending"}
    ).execute()

    app.dependency_overrides[get_current_user] = lambda: {"id": employer_id, "user_type": "employer"}
    try:
        res = client.patch(f"/api/v1/applications/{app_id}", json={"status": "accepted"})
        assert res.status_code == 200, res.text
        assert res.json()["status"] == "accepted"
    finally:
        app.dependency_overrides.clear()


def test_accept_blocked_at_capacity(env):
    # The DB trigger trg_sync_workers_assigned recounts accepted apps on every
    # INSERT/UPDATE to applications, so a manual workers_assigned write gets
    # overwritten. We must create a real accepted application from a second
    # worker so the trigger itself sets workers_assigned=1.
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    job_id = _seed_job(db, employer_id, needed=1, status="open")

    # Create a second worker and accept their application so the trigger
    # sets workers_assigned=1 and flips job status to "assigned".
    worker2_id = str(uuid.uuid4())
    db.table("users").insert(
        {"id": worker2_id, "phone_number": f"+2{worker2_id[:10]}", "user_type": "worker"}
    ).execute()
    db.table("worker_profiles").insert({"user_id": worker2_id}).execute()
    _seed_app(db, job_id, worker2_id, status="accepted")
    # Trigger now sets workers_assigned=1; accept the job via the service so
    # status also flips to "assigned".
    fake_employer = {"id": employer_id, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_employer

    # Now seed the env worker's pending application and try to accept it.
    app_id = _seed_app(db, job_id, worker_id)
    try:
        res = client.patch(f"/api/v1/applications/{app_id}", json={"status": "accepted"})
        assert res.status_code == 400, res.text
    finally:
        # Clean up second worker fully so no orphan rows remain.
        db.table("applications").delete().eq("worker_id", worker2_id).execute()
        db.table("worker_profiles").delete().eq("user_id", worker2_id).execute()
        db.table("users").delete().eq("id", worker2_id).execute()
        app.dependency_overrides.clear()


def test_reject_leaves_assigned_unchanged(env):
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    job_id = _seed_job(db, employer_id, needed=2, status="open")
    app_id = _seed_app(db, job_id, worker_id)

    fake = {"id": employer_id, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake
    try:
        res = client.patch(f"/api/v1/applications/{app_id}", json={"status": "rejected"})
        assert res.status_code == 200, res.text
        assert res.json()["status"] == "rejected"
        job = db.table("jobs").select("workers_assigned, status").eq("id", job_id).execute().data[0]
        assert job["workers_assigned"] == 0
        assert job["status"] == "open"
    finally:
        app.dependency_overrides.clear()


def test_withdraw_accepted_decrements_and_reverts(env):
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    job_id = _seed_job(db, employer_id, needed=1, status="assigned", start_date=_FUTURE)
    db.table("jobs").update({"workers_assigned": 1}).eq("id", job_id).execute()
    app_id = _seed_app(db, job_id, worker_id, status="accepted")

    fake = {"id": worker_id, "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake
    try:
        res = client.patch(
            f"/api/v1/applications/{app_id}",
            json={"status": "withdrawn", "reason": "Plans changed"},
        )
        assert res.status_code == 200, res.text
        assert res.json()["withdrawn_reason"] == "Plans changed"
        job = db.table("jobs").select("workers_assigned, status").eq("id", job_id).execute().data[0]
        assert job["workers_assigned"] == 0
        assert job["status"] == "open"
    finally:
        app.dependency_overrides.clear()


def test_withdraw_blocked_on_or_after_start_date(env):
    """Cancellation window: a worker cannot withdraw once the job's start
    date has arrived. The accept stays intact (no DB change)."""
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    # start_date in the past -> on/after start -> withdraw must be rejected.
    job_id = _seed_job(db, employer_id, needed=1, status="assigned", start_date="2020-01-01")
    db.table("jobs").update({"workers_assigned": 1}).eq("id", job_id).execute()
    app_id = _seed_app(db, job_id, worker_id, status="accepted")

    app.dependency_overrides[get_current_user] = lambda: {"id": worker_id, "user_type": "worker"}
    try:
        res = client.patch(
            f"/api/v1/applications/{app_id}",
            json={"status": "withdrawn"},
        )
        assert res.status_code == 400, res.text
        # unchanged
        a = db.table("applications").select("status").eq("id", app_id).execute().data[0]
        assert a["status"] == "accepted"
        job = db.table("jobs").select("workers_assigned, status").eq("id", job_id).execute().data[0]
        assert job["workers_assigned"] == 1
        assert job["status"] == "assigned"
    finally:
        app.dependency_overrides.clear()


def test_accept_other_employer_forbidden(env):
    db, employer_id, worker_id = env["db"], env["employer_id"], env["worker_id"]
    job_id = _seed_job(db, employer_id, needed=1, status="open")
    app_id = _seed_app(db, job_id, worker_id)

    other = str(uuid.uuid4())
    fake = {"id": other, "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake
    try:
        res = client.patch(f"/api/v1/applications/{app_id}", json={"status": "accepted"})
        assert res.status_code == 403, res.text
    finally:
        app.dependency_overrides.clear()
