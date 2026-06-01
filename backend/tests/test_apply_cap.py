import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_worker
from app.supabase_client import get_supabase

client = TestClient(app)


def _cat(db) -> str:
    return db.table("categories").select("id").limit(1).execute().data[0]["id"]


def _seed_open_job(db, employer_id: str) -> str:
    job_id = str(uuid.uuid4())
    db.table("jobs").insert({
        "id": job_id, "employer_id": employer_id, "category_id": _cat(db),
        "title": f"cap-test-{job_id}", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 5,
        "start_date": "2026-01-01", "end_date": "2026-01-02", "status": "open",
    }).execute()
    return job_id


@pytest.fixture
def env():
    db = get_supabase()
    employer_id = str(uuid.uuid4())
    worker_id = str(uuid.uuid4())
    db.table("users").insert(
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert({"user_id": employer_id, "business_name": "CapCo"}).execute()
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


def test_apply_blocked_when_two_accepted(env):
    db, worker_id, employer_id = env["db"], env["worker_id"], env["employer_id"]
    # Two already-accepted applications saturate the cap.
    for _ in range(2):
        jid = _seed_open_job(db, employer_id)
        db.table("applications").insert(
            {"job_id": jid, "worker_id": worker_id, "status": "accepted"}
        ).execute()
    target = _seed_open_job(db, employer_id)

    fake = {"id": worker_id, "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake
    app.dependency_overrides[require_worker] = lambda: fake
    try:
        res = client.post(f"/api/v1/jobs/{target}/apply")
        assert res.status_code == 409, res.text
    finally:
        app.dependency_overrides.clear()


def test_apply_allowed_with_one_accepted(env):
    db, worker_id, employer_id = env["db"], env["worker_id"], env["employer_id"]
    jid = _seed_open_job(db, employer_id)
    db.table("applications").insert(
        {"job_id": jid, "worker_id": worker_id, "status": "accepted"}
    ).execute()
    target = _seed_open_job(db, employer_id)

    fake = {"id": worker_id, "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake
    app.dependency_overrides[require_worker] = lambda: fake
    try:
        res = client.post(f"/api/v1/jobs/{target}/apply")
        assert res.status_code == 201, res.text
    finally:
        app.dependency_overrides.clear()
