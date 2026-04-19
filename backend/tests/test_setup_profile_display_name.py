import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_jwt_payload
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def fresh_user_jwt():
    user_id = str(uuid.uuid4())
    phone = f"+1{user_id[:10]}"
    app.dependency_overrides[get_jwt_payload] = lambda: {"sub": user_id, "phone": phone}
    yield {"sub": user_id, "phone": phone}
    db = get_supabase()
    # Cleanup — setup_profile inserts into users and worker_profiles/employer_profiles
    db.table("worker_profiles").delete().eq("user_id", user_id).execute()
    db.table("employer_profiles").delete().eq("user_id", user_id).execute()
    db.table("users").delete().eq("id", user_id).execute()
    app.dependency_overrides.clear()


def test_setup_profile_stores_display_name(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "worker", "display_name": "Alice"},
    )
    assert res.status_code == 200

    db = get_supabase()
    row = db.table("users").select("display_name").eq("id", fresh_user_jwt["sub"]).execute()
    assert row.data[0]["display_name"] == "Alice"


def test_setup_profile_without_display_name_leaves_null(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "employer"},
    )
    assert res.status_code == 200

    db = get_supabase()
    row = db.table("users").select("display_name").eq("id", fresh_user_jwt["sub"]).execute()
    assert row.data[0]["display_name"] is None


def test_setup_profile_rejects_empty_display_name(fresh_user_jwt):
    res = client.post(
        "/api/v1/auth/setup-profile",
        json={"user_type": "worker", "display_name": "   "},
    )
    assert res.status_code == 422
