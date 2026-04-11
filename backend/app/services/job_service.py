import hashlib
import json
from supabase import Client
from app.redis_client import get_redis

CACHE_TTL = 60  # seconds
CACHE_PREFIX = "jobs:feed:"


def _cache_key(params: dict) -> str:
    serialized = json.dumps(params, sort_keys=True, default=str)
    digest = hashlib.sha256(serialized.encode()).hexdigest()[:16]
    return f"{CACHE_PREFIX}{digest}"


async def get_jobs_feed(
    db: Client,
    lat: float | None,
    lng: float | None,
    radius_km: float,
    category_id: str | None,
    filter_status: str,
    page: int,
    page_size: int,
) -> dict:
    # Without lat/lng, skip geo filter — plain paginated list
    if lat is None or lng is None:
        return _plain_feed(db, category_id, filter_status, page, page_size)

    cache_params = {
        "lat": round(lat, 4),
        "lng": round(lng, 4),
        "radius_km": radius_km,
        "category_id": category_id,
        "status": filter_status,
        "page": page,
        "page_size": page_size,
    }
    key = _cache_key(cache_params)
    redis = get_redis()

    cached = await redis.get(key)
    if cached:
        return json.loads(cached)

    offset = (page - 1) * page_size
    result = db.rpc("get_nearby_jobs", {
        "user_lat": lat,
        "user_lng": lng,
        "radius_meters": radius_km * 1000,
        "filter_status": filter_status,
        "filter_category": category_id,
        "page_offset": offset,
        "page_limit": page_size,
    }).execute()

    rows = result.data or []
    total = rows[0]["total_count"] if rows else 0

    payload = {
        "data": rows,
        "page": page,
        "page_size": page_size,
        "total": total,
    }

    await redis.setex(key, CACHE_TTL, json.dumps(payload, default=str))
    return payload


def _plain_feed(
    db: Client,
    category_id: str | None,
    filter_status: str,
    page: int,
    page_size: int,
) -> dict:
    offset = (page - 1) * page_size
    query = (
        db.table("jobs")
        .select("*", count="exact")
        .eq("status", filter_status)
        .order("created_at", desc=True)
        .range(offset, offset + page_size - 1)
    )
    if category_id:
        query = query.eq("category_id", category_id)

    result = query.execute()
    return {
        "data": result.data or [],
        "page": page,
        "page_size": page_size,
        "total": result.count or 0,
    }


async def invalidate_job_cache() -> None:
    redis = get_redis()
    keys = await redis.keys(f"{CACHE_PREFIX}*")
    if keys:
        await redis.delete(*keys)
