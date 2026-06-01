-- 008_add_applications_withdrawn_reason.sql
-- Adds a free-text reason captured when a worker withdraws or an employer
-- cancels a job (cascade sets a fixed reason). Nullable for backwards
-- compatibility with rows created before Plan B.
-- NOTE: completion columns (worker_completed_at / employer_completed_at) and
-- the 'completed' status value land in Plan C, not here.

ALTER TABLE applications ADD COLUMN IF NOT EXISTS withdrawn_reason TEXT NULL;
