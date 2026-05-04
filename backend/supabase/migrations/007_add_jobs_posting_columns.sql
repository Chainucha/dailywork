-- 007_add_jobs_posting_columns.sql
-- Adds five nullable columns to jobs for the posting wizard:
--  - start_time / end_time: hours within the start_date/end_date window
--  - is_urgent: employer-flagged urgency (drives UI badge + sort weight later)
--  - address_text: human-readable address from Nominatim reverse-geocode
--  - cancellation_reason: free-text reason captured from cancel modal
-- All nullable for backwards compatibility with rows created before Plan A.

ALTER TABLE jobs ADD COLUMN IF NOT EXISTS start_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS end_time TIME NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS address_text TEXT NULL;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL;
