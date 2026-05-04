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
