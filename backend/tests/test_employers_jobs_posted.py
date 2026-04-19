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
