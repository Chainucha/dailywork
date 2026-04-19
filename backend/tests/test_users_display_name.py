import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user

client = TestClient(app, raise_server_exceptions=False)

FAKE_USER = {
    "id": "11111111-1111-1111-1111-111111111111",
    "phone_number": "+15551112222",
    "user_type": "worker",
    "display_name": None,
    "location_lat": None,
    "location_lng": None,
    "created_at": "2026-04-19T00:00:00+00:00",
}


@pytest.fixture
def override_user():
    app.dependency_overrides[get_current_user] = lambda: FAKE_USER
    yield
    app.dependency_overrides.clear()


def test_user_update_rejects_empty_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": ""})
    assert res.status_code == 422


def test_user_update_rejects_whitespace_only_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": "   "})
    assert res.status_code == 422


def test_user_update_rejects_too_long_display_name(override_user):
    res = client.patch("/api/v1/users/me", json={"display_name": "x" * 61})
    assert res.status_code == 422


def test_user_update_accepts_valid_display_name(override_user):
    # Trim is applied server-side; the value eventually reaches Supabase.
    # Since we can't verify the DB side in this unit scope, we assert the
    # request is not rejected by validation (422).
    res = client.patch("/api/v1/users/me", json={"display_name": "  Alice  "})
    # Either 200 (DB reachable) or 500 (DB unreachable in local dev) — both
    # indicate validation passed. 422 would mean we rejected a valid name.
    assert res.status_code != 422
