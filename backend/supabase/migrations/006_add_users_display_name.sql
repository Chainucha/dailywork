-- 006_add_users_display_name.sql
-- Adds a nullable display_name column to users. Existing rows remain NULL.
-- Flutter falls back to phone_number when NULL; new worker onboarding
-- enforces a non-empty value; employers use business_name instead.

ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Length guard at the DB level; also enforced in Pydantic.
ALTER TABLE users
  ADD CONSTRAINT users_display_name_length
  CHECK (display_name IS NULL OR char_length(display_name) BETWEEN 1 AND 60);
