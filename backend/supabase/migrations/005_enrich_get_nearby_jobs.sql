-- Migration 005: Enrich get_nearby_jobs RPC with category_name, employer_name, applicant_count.
-- Uses CREATE OR REPLACE — safe to run against an existing function.

CREATE OR REPLACE FUNCTION get_nearby_jobs(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION,
    filter_status TEXT DEFAULT 'open',
    filter_category UUID DEFAULT NULL,
    page_offset INT DEFAULT 0,
    page_limit INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    employer_id UUID,
    category_id UUID,
    title TEXT,
    description TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    wage_per_day NUMERIC,
    workers_needed INT,
    workers_assigned INT,
    status TEXT,
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMPTZ,
    distance_meters DOUBLE PRECISION,
    total_count BIGINT,
    category_name TEXT,
    employer_name TEXT,
    applicant_count BIGINT
)
LANGUAGE sql STABLE AS $$
    SELECT
        j.id,
        j.employer_id,
        j.category_id,
        j.title,
        j.description,
        j.location_lat,
        j.location_lng,
        j.wage_per_day,
        j.workers_needed,
        j.workers_assigned,
        j.status::TEXT,
        j.start_date,
        j.end_date,
        j.created_at,
        ST_Distance(
            j.location_point,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
        ) AS distance_meters,
        COUNT(*) OVER () AS total_count,
        c.name AS category_name,
        ep.business_name AS employer_name,
        COALESCE(
            (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.id),
            0
        ) AS applicant_count
    FROM jobs j
    LEFT JOIN categories c ON c.id = j.category_id
    LEFT JOIN employer_profiles ep ON ep.user_id = j.employer_id
    WHERE
        j.status::TEXT = filter_status
        AND (filter_category IS NULL OR j.category_id = filter_category)
        AND ST_DWithin(
            j.location_point,
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
            radius_meters
        )
    ORDER BY distance_meters ASC
    LIMIT page_limit OFFSET page_offset;
$$;
