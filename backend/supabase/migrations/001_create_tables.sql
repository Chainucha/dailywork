-- Enable PostGIS extension (run this first in Supabase SQL editor)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enums
CREATE TYPE user_type_enum AS ENUM ('worker', 'employer');
CREATE TYPE job_status_enum AS ENUM ('open', 'assigned', 'in_progress', 'completed', 'cancelled');
CREATE TYPE application_status_enum AS ENUM ('pending', 'accepted', 'rejected', 'withdrawn');

-- Categories (no FK deps, seed first)
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    icon_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Users (core identity)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL UNIQUE,
    user_type user_type_enum NOT NULL,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    fcm_token TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Worker profiles
CREATE TABLE worker_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    skills TEXT[] DEFAULT '{}',
    availability_status BOOLEAN DEFAULT true,
    daily_wage_expectation NUMERIC(10, 2),
    rating_avg NUMERIC(3, 2) DEFAULT 0,
    total_reviews INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Employer profiles
CREATE TABLE employer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    business_type TEXT,
    rating_avg NUMERIC(3, 2) DEFAULT 0,
    total_reviews INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Jobs
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id),
    title TEXT NOT NULL,
    description TEXT,
    location_point GEOGRAPHY(POINT, 4326),
    location_lat DOUBLE PRECISION NOT NULL,
    location_lng DOUBLE PRECISION NOT NULL,
    wage_per_day NUMERIC(10, 2) NOT NULL,
    workers_needed INT NOT NULL DEFAULT 1,
    workers_assigned INT NOT NULL DEFAULT 0,
    status job_status_enum NOT NULL DEFAULT 'open',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Applications
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status application_status_enum NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (job_id, worker_id)
);

-- Reviews (bidirectional)
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (reviewer_id, job_id)
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);
