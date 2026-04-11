-- ─────────────────────────────────────────
-- 1. updated_at auto-maintenance
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_jobs_updated_at
    BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_applications_updated_at
    BEFORE UPDATE ON applications FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_worker_profiles_updated_at
    BEFORE UPDATE ON worker_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_employer_profiles_updated_at
    BEFORE UPDATE ON employer_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ─────────────────────────────────────────
-- 2. location_point sync (lat/lng → GEOGRAPHY)
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_location_point()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location_point = ST_SetSRID(
        ST_MakePoint(NEW.location_lng, NEW.location_lat), 4326
    )::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_location_point
    BEFORE INSERT OR UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION sync_location_point();


-- ─────────────────────────────────────────
-- 3. workers_assigned count sync
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_workers_assigned()
RETURNS TRIGGER AS $$
DECLARE
    target_job_id UUID;
BEGIN
    target_job_id := COALESCE(NEW.job_id, OLD.job_id);
    UPDATE jobs
    SET workers_assigned = (
        SELECT COUNT(*) FROM applications
        WHERE job_id = target_job_id AND status = 'accepted'
    )
    WHERE id = target_job_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_workers_assigned
    AFTER INSERT OR UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION sync_workers_assigned();


-- ─────────────────────────────────────────
-- 4. Rating average recalculation
-- ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION recalculate_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating NUMERIC(3, 2);
    review_count INT;
    target_type user_type_enum;
BEGIN
    SELECT user_type INTO target_type FROM users WHERE id = NEW.reviewee_id;

    SELECT AVG(rating), COUNT(*)
    INTO avg_rating, review_count
    FROM reviews WHERE reviewee_id = NEW.reviewee_id;

    IF target_type = 'worker' THEN
        UPDATE worker_profiles
        SET rating_avg = avg_rating, total_reviews = review_count
        WHERE user_id = NEW.reviewee_id;
    ELSE
        UPDATE employer_profiles
        SET rating_avg = avg_rating, total_reviews = review_count
        WHERE user_id = NEW.reviewee_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recalculate_rating
    AFTER INSERT ON reviews
    FOR EACH ROW EXECUTE FUNCTION recalculate_rating();


-- ─────────────────────────────────────────
-- 5. get_nearby_jobs RPC function
--    Called from Python via db.rpc("get_nearby_jobs", {...})
-- ─────────────────────────────────────────
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
    total_count BIGINT
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
        COUNT(*) OVER () AS total_count
    FROM jobs j
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
