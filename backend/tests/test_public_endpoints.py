import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_list_jobs_without_auth():
    """GET /api/v1/jobs/ should not return 401/403 without Authorization header."""
    response = client.get("/api/v1/jobs/", params={"lat": 12.97, "lng": 77.59})
    assert response.status_code != 401
    assert response.status_code != 403


def test_list_categories_without_auth():
    """GET /api/v1/categories/ should not return 401/403 without Authorization header."""
    response = client.get("/api/v1/categories/")
    assert response.status_code != 401
    assert response.status_code != 403


def test_get_job_without_auth():
    """GET /api/v1/jobs/{id} should not return 401/403 without Authorization header."""
    # Fake UUID — expect 404 (not found) not 401 (unauthorized)
    response = client.get("/api/v1/jobs/00000000-0000-0000-0000-000000000000")
    assert response.status_code != 401
    assert response.status_code != 403


def test_create_job_still_requires_auth():
    """POST /api/v1/jobs/ must still require auth."""
    response = client.post("/api/v1/jobs/", json={
        "title": "test",
        "category_id": "00000000-0000-0000-0000-000000000000",
        "location_lat": 12.97,
        "location_lng": 77.59,
        "wage_per_day": 500,
        "workers_needed": 1,
        "start_date": "2026-05-01",
        "end_date": "2026-05-05",
    })
    assert response.status_code in (401, 403)
