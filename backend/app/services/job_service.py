from collections import Counter
from supabase import Client


def _enrich_rows_batch(db: Client, rows: list[dict]) -> list[dict]:
    """Enriches a list of job dicts with category_name, employer_name, applicant_count.

    Works for both:
    - PostgREST rows that already have embedded 'categories' and 'employer_profiles' dicts
      (from a .select("*, categories(name), employer_profiles(business_name)") call), and
    - Plain dict rows from the get_nearby_jobs RPC (which already include category_name,
      employer_name, and applicant_count columns directly after migration 005).
    """
    if not rows:
        return rows

    # If the RPC has already populated enrichment columns, no further work needed.
    if "category_name" in rows[0]:
        return [dict(r) for r in rows]

    job_ids = [r["id"] for r in rows]

    # Determine whether we have embedded objects (PostgREST join) or need batch fetches.
    need_category_fetch = "categories" not in rows[0]
    need_employer_fetch = "employer_profiles" not in rows[0]

    category_map: dict = {}
    employer_map: dict = {}

    if need_category_fetch:
        cat_ids = list({r["category_id"] for r in rows})
        cats = db.table("categories").select("id, name").in_("id", cat_ids).execute()
        category_map = {c["id"]: c["name"] for c in (cats.data or [])}

    if need_employer_fetch:
        emp_ids = list({r["employer_id"] for r in rows})
        emps = (
            db.table("employer_profiles")
            .select("user_id, business_name")
            .in_("user_id", emp_ids)
            .execute()
        )
        employer_map = {e["user_id"]: e["business_name"] for e in (emps.data or [])}

    # Batch applicant counts — one query, counted in Python.
    apps = db.table("applications").select("job_id").in_("job_id", job_ids).execute()
    counts: Counter = Counter(a["job_id"] for a in (apps.data or []))

    enriched = []
    for row in rows:
        r = dict(row)
        if need_category_fetch:
            r["category_name"] = category_map.get(r["category_id"])
        else:
            r["category_name"] = (r.pop("categories", None) or {}).get("name")

        if need_employer_fetch:
            r["employer_name"] = employer_map.get(r["employer_id"])
        else:
            r["employer_name"] = (r.pop("employer_profiles", None) or {}).get("business_name")

        r["applicant_count"] = counts.get(r["id"], 0)
        enriched.append(r)
    return enriched


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

    return {
        "data": rows,
        "page": page,
        "page_size": page_size,
        "total": total,
    }


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
        .select("*, categories(name)", count="exact")
        .eq("status", filter_status)
        .order("created_at", desc=True)
        .range(offset, offset + page_size - 1)
    )
    if category_id:
        query = query.eq("category_id", category_id)

    result = query.execute()
    rows = _enrich_rows_batch(db, result.data or [])
    return {
        "data": rows,
        "page": page,
        "page_size": page_size,
        "total": result.count or 0,
    }


async def cancel_job(db: Client, job_id: str, employer_id: str, reason: str | None) -> dict:
    """Cancels a job and cascades to all pending/accepted applications.

    Raises ValueError on guard failures (router converts to 400/403/404).
    """
    job_result = db.table("jobs").select("*").eq("id", job_id).execute()
    if not job_result.data:
        raise ValueError("not_found")
    job = job_result.data[0]
    if job["employer_id"] != employer_id:
        raise ValueError("forbidden")
    if job["status"] not in ("open", "assigned"):
        raise ValueError("invalid_status")

    update = {"status": "cancelled"}
    if reason is not None:
        update["cancellation_reason"] = reason
    db.table("jobs").update(update).eq("id", job_id).execute()

    # Cascade — set every pending/accepted application on this job to withdrawn.
    db.table("applications").update({"status": "withdrawn"}) \
        .eq("job_id", job_id) \
        .in_("status", ["pending", "accepted"]) \
        .execute()

    refreshed = db.table("jobs").select("*").eq("id", job_id).execute().data[0]
    return refreshed
