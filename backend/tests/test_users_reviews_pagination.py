import pytest
import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_current_user
from app.supabase_client import get_supabase

client = TestClient(app)


@pytest.fixture
def seeded_reviews():
    """Seed a reviewee and 25 reviewers with one review each."""
    db = get_supabase()
    reviewee_id = str(uuid.uuid4())
    employer_id = str(uuid.uuid4())

    db.table("users").insert([
        {"id": reviewee_id, "phone_number": f"+1{reviewee_id[:10]}", "user_type": "worker"},
        {"id": employer_id, "phone_number": f"+1{employer_id[:10]}", "user_type": "employer", "display_name": "Prestige"},
    ]).execute()
    db.table("worker_profiles").insert({"user_id": reviewee_id}).execute()
    db.table("employer_profiles").insert({"user_id": employer_id, "business_name": "Prestige"}).execute()

    category_id = db.table("categories").select("id").limit(1).execute().data[0]["id"]

    job = db.table("jobs").insert({
        "employer_id": employer_id,
        "category_id": category_id,
        "title": "job", "location_lat": 0, "location_lng": 0,
        "wage_per_day": 100, "workers_needed": 1,
        "start_date": "2026-01-01", "end_date": "2026-01-02",
        "status": "completed",
    }).execute().data[0]

    reviewer_ids = []
    for i in range(25):
        rid = str(uuid.uuid4())
        reviewer_ids.append(rid)
        display_name = f"Reviewer {i}" if i < 15 else None
        db.table("users").insert({
            "id": rid,
            "phone_number": f"+1900{i:07d}",
            "user_type": "employer",
            "display_name": display_name,
        }).execute()
        db.table("reviews").insert({
            "reviewer_id": rid,
            "reviewee_id": reviewee_id,
            "job_id": job["id"],
            "rating": (i % 5) + 1,
            "comment": f"comment {i}",
        }).execute()

    yield {"reviewee_id": reviewee_id, "reviewer_ids": reviewer_ids, "employer_id": employer_id, "job_id": job["id"]}

    db.table("reviews").delete().eq("reviewee_id", reviewee_id).execute()
    db.table("jobs").delete().eq("id", job["id"]).execute()
    db.table("employer_profiles").delete().eq("user_id", employer_id).execute()
    db.table("worker_profiles").delete().eq("user_id", reviewee_id).execute()
    db.table("users").delete().in_("id", reviewer_ids + [reviewee_id, employer_id]).execute()


@pytest.fixture
def any_auth():
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "44444444-4444-4444-4444-444444444444", "user_type": "worker",
    }
    yield
    app.dependency_overrides.clear()


def test_reviews_default_pagination_returns_20(seeded_reviews, any_auth):
    res = client.get(f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews")
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 25
    assert body["limit"] == 20
    assert body["offset"] == 0
    assert len(body["items"]) == 20


def test_reviews_respects_limit_and_offset(seeded_reviews, any_auth):
    res = client.get(
        f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
        params={"limit": 10, "offset": 20},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 25
    assert len(body["items"]) == 5


def test_reviews_flattens_reviewer_display_name(seeded_reviews, any_auth):
    res = client.get(f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
                     params={"limit": 50, "offset": 0})
    items = res.json()["items"]
    assert len(items) == 25
    named = [i for i in items if i["reviewer_display_name"].startswith("Reviewer ")]
    phone_fallback = [i for i in items if i["reviewer_display_name"].startswith("+1900")]
    assert len(named) == 15
    assert len(phone_fallback) == 10


def test_reviews_rejects_limit_over_50(seeded_reviews, any_auth):
    res = client.get(
        f"/api/v1/users/{seeded_reviews['reviewee_id']}/reviews",
        params={"limit": 51, "offset": 0},
    )
    assert res.status_code == 422
