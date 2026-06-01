import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user, require_employer
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
    db.table("employer_profiles").insert({"user_id": employer_id, "business_name": "ListCo"}).execute()
    db.table("users").insert({
        "id": worker_id, "phone_number": "+19998887777",
        "user_type": "worker", "display_name": "Ravi Kumar",
    }).execute()
    db.table("worker_profiles").insert({"user_id": worker_id, "rating_avg": 4.5}).execute()
    job_id = str(uuid.uuid4())
    db.table("jobs").insert({
        "id": job_id, "employer_id": employer_id, "category_id": _cat(db),
        "title": f"list-{job_id}", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 2,
        "start_date": "2026-01-01", "end_date": "2026-01-02", "status": "open",
    }).execute()
    db.table("applications").insert(
        {"job_id": job_id, "worker_id": worker_id, "status": "pending"}
    ).execute()
    yield {"db": db, "employer_id": employer_id, "worker_id": worker_id, "job_id": job_id}
    db.table("applications").delete().eq("worker_id", worker_id).execute()
    db.table("jobs").delete().eq("employer_id", employer_id).execute()
    db.table("worker_profiles").delete().eq("user_id", worker_id).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("users").delete().eq("id", worker_id).execute()
    db.table("users").delete().eq("id", employer_id).execute()


def test_applicant_list_carries_name_phone_rating(env):
    fake = {"id": env["employer_id"], "user_type": "employer"}
    app.dependency_overrides[get_current_user] = lambda: fake
    app.dependency_overrides[require_employer] = lambda: fake
    try:
        res = client.get(f"/api/v1/jobs/{env['job_id']}/applications")
        assert res.status_code == 200, res.text
        rows = res.json()["data"]
        assert len(rows) == 1
        row = rows[0]
        assert row["display_name"] == "Ravi Kumar"
        assert row["phone_number"] == "+19998887777"
        assert row["rating_avg"] == 4.5
        assert row["status"] == "pending"
        assert "application_id" in row
    finally:
        app.dependency_overrides.clear()
