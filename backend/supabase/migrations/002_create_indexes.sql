-- Geo index for proximity search
CREATE INDEX idx_jobs_location ON jobs USING GIST (location_point);

-- Job filtering (most common query patterns)
CREATE INDEX idx_jobs_status_created ON jobs (status, created_at DESC);
CREATE INDEX idx_jobs_employer ON jobs (employer_id);
CREATE INDEX idx_jobs_category ON jobs (category_id);

-- Application lookups
CREATE INDEX idx_applications_job ON applications (job_id);
CREATE INDEX idx_applications_worker ON applications (worker_id);
CREATE INDEX idx_applications_job_status ON applications (job_id, status);

-- Notification inbox (unread first)
CREATE INDEX idx_notifications_user_unread ON notifications (user_id, is_read, created_at DESC);

-- Reviews per user
CREATE INDEX idx_reviews_reviewee ON reviews (reviewee_id);
CREATE INDEX idx_reviews_job ON reviews (job_id);
