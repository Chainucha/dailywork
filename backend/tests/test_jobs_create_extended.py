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
