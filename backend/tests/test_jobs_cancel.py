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
