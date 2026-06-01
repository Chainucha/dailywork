import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_worker
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_worker_with_applications():
    """One worker who applied to 3 jobs: pending, accepted, withdrawn."""
    db = get_supabase()
    wid = str(uuid.uuid4())
    eid = str(uuid.uuid4())
    db.table("users").insert(
        {"id": wid, "phone_number": f"+1{wid[:10]}", "user_type": "worker"}
    ).execute()
    db.table("worker_profiles").insert({"user_id": wid}).execute()
    db.table("users").insert(
        {"id": eid, "phone_number": f"+1{eid[:10]}", "user_type": "employer"}
    ).execute()
    db.table("employer_profiles").insert(
        {"user_id": eid, "business_name": "AppCo"}
    ).execute()
    cat_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]

    job_ids = []
    for app_status in ("pending", "accepted", "withdrawn"):
        job = db.table("jobs").insert({
            "employer_id": eid,
            "category_id": cat_id,
            "title": f"app-job-{app_status}-{uuid.uuid4()}",
            "location_lat": 0, "location_lng": 0,
            "wage_per_day": 100, "workers_needed": 1,
            "start_date": "2026-01-01", "end_date": "2026-01-02",
            "status": "open",
        }).execute().data[0]
        job_ids.append(job["id"])
        db.table("applications").insert({
            "job_id": job["id"],
            "worker_id": wid,
            "status": app_status,
        }).execute()

    yield wid
    db.table("applications").delete().eq("worker_id", wid).execute()
    for jid in job_ids:
        db.table("jobs").delete().eq("id", jid).execute()
    db.table("worker_profiles").delete().eq("user_id", wid).execute()
    db.table("employer_profiles").delete().eq("user_id", eid).execute()
    db.table("users").delete().eq("id", wid).execute()
    db.table("users").delete().eq("id", eid).execute()


def test_worker_me_applications_groups_by_status(seeded_worker_with_applications):
    fake = {"id": seeded_worker_with_applications, "user_type": "worker"}
    app.dependency_overrides[get_current_user] = lambda: fake
    app.dependency_overrides[require_worker] = lambda: fake
    try:
        res = client.get("/api/v1/workers/me/applications")
        assert res.status_code == 200, res.text
        body = res.json()
        assert len(body["pending"]) == 1
        assert len(body["accepted"]) == 1
        assert len(body["withdrawn"]) == 1
        assert len(body["rejected"]) == 0
        row = body["pending"][0]
        assert row["application_status"] == "pending"
        assert "application_id" in row
        assert "title" in row and "wage_per_day" in row
    finally:
        app.dependency_overrides.clear()


def test_worker_me_applications_requires_worker(seeded_worker_with_applications):
    fake_employer = {"id": str(uuid.uuid4()), "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake_employer
    try:
        res = client.get("/api/v1/workers/me/applications")
        assert res.status_code == 403, res.text
    finally:
        app.dependency_overrides.clear()
