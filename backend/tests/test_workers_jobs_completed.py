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
