-- =============================================================================
-- seed.sql — Development test data for Daily Wage Worker Job Board
-- =============================================================================
-- Runs automatically after migrations via: supabase db reset
-- Categories are already seeded by 004_seed_categories.sql — NOT repeated here.
--
-- Insert order (FK-safe):
--   1. users
--   2. worker_profiles
--   3. employer_profiles
--   4. jobs
--   5. applications
--   6. reviews
--   7. notifications
-- =============================================================================


-- =============================================================================
-- 1. USERS  (5 workers + 3 employers)
--    Hardcoded UUIDs so downstream inserts can reference them directly.
--    location_point is NOT inserted — the sync_location_point trigger handles it.
-- =============================================================================

INSERT INTO users (id, phone_number, user_type, location_lat, location_lng) VALUES
    -- Workers
    ('11111111-1111-1111-1111-111111111111', '+15550101001', 'worker',   12.9716, 77.5946),
    ('22222222-2222-2222-2222-222222222222', '+15550101002', 'worker',   12.9650, 77.6000),
    ('33333333-3333-3333-3333-333333333333', '+15550101003', 'worker',   12.9800, 77.5800),
    ('44444444-4444-4444-4444-444444444444', '+15550101004', 'worker',   12.9750, 77.6100),
    ('55555555-5555-5555-5555-555555555555', '+15550101005', 'worker',   12.9600, 77.5700),
    -- Employers
    ('eeeeeeee-1111-1111-1111-111111111111', '+15550102001', 'employer', 12.9716, 77.5946),
    ('eeeeeeee-2222-2222-2222-222222222222', '+15550102002', 'employer', 12.9680, 77.6050),
    ('eeeeeeee-3333-3333-3333-333333333333', '+15550102003', 'employer', 12.9770, 77.5900);


-- =============================================================================
-- 2. WORKER PROFILES
--    rating_avg and total_reviews are NOT set — recalculate_rating trigger handles them.
-- =============================================================================

INSERT INTO worker_profiles (user_id, skills, availability_status, daily_wage_expectation) VALUES
    ('11111111-1111-1111-1111-111111111111', '{masonry,plastering,tiling}', true,  850.00),
    ('22222222-2222-2222-2222-222222222222', '{cleaning,laundry,ironing}',  true,  500.00),
    ('33333333-3333-3333-3333-333333333333', '{driving,loading,packing}',   false, 700.00),
    ('44444444-4444-4444-4444-444444444444', '{cooking,catering}',          true,  600.00),
    ('55555555-5555-5555-5555-555555555555', '{painting,whitewashing}',     true,  750.00);


-- =============================================================================
-- 3. EMPLOYER PROFILES
--    rating_avg and total_reviews are NOT set — recalculate_rating trigger handles them.
-- =============================================================================

INSERT INTO employer_profiles (user_id, business_name, business_type) VALUES
    ('eeeeeeee-1111-1111-1111-111111111111', 'Sunrise Builders',    'Construction'),
    ('eeeeeeee-2222-2222-2222-222222222222', 'CleanPro Services',   'Cleaning'),
    ('eeeeeeee-3333-3333-3333-333333333333', 'QuickMove Logistics', 'Logistics');


-- =============================================================================
-- 4. JOBS  (12 total, varied statuses)
--    location_point is NOT inserted — sync_location_point trigger handles it.
--    workers_assigned is NOT inserted — sync_workers_assigned trigger handles it.
--    category_id resolved via subquery on categories.name (seeded in migration 004).
-- =============================================================================

INSERT INTO jobs (
    id,
    employer_id,
    category_id,
    title,
    description,
    location_lat,
    location_lng,
    wage_per_day,
    workers_needed,
    status,
    start_date,
    end_date
) VALUES

    -- j1: open, Construction, e1
    (
        'aaaaaaaa-0001-0000-0000-000000000000',
        'eeeeeeee-1111-1111-1111-111111111111',
        (SELECT id FROM categories WHERE name = 'Construction'),
        'Site Mason – MG Road Project',
        'Masonry work on a commercial site near MG Road. Experience with brick-laying required.',
        12.9756, 77.6073,
        900.00, 3, 'open',
        CURRENT_DATE + INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '5 days'
    ),

    -- j2: open, Construction, e1
    (
        'aaaaaaaa-0002-0000-0000-000000000000',
        'eeeeeeee-1111-1111-1111-111111111111',
        (SELECT id FROM categories WHERE name = 'Construction'),
        'Concrete Mixer Operator',
        'Operate concrete mixer and assist in pouring for a residential project.',
        12.9698, 77.5945,
        1000.00, 2, 'open',
        CURRENT_DATE + INTERVAL '3 days',
        CURRENT_DATE + INTERVAL '10 days'
    ),

    -- j3: open, Cleaning, e2
    (
        'aaaaaaaa-0003-0000-0000-000000000000',
        'eeeeeeee-2222-2222-2222-222222222222',
        (SELECT id FROM categories WHERE name = 'Cleaning'),
        'Office Deep Cleaning',
        'Deep clean of a 3-floor commercial office including washrooms and common areas.',
        12.9610, 77.6020,
        550.00, 4, 'open',
        CURRENT_DATE + INTERVAL '0 days',
        CURRENT_DATE + INTERVAL '1 day'
    ),

    -- j4: open, Cleaning, e2
    (
        'aaaaaaaa-0004-0000-0000-000000000000',
        'eeeeeeee-2222-2222-2222-222222222222',
        (SELECT id FROM categories WHERE name = 'Cleaning'),
        'Apartment Move-out Cleaning',
        'Thorough cleaning of a 2BHK apartment after tenant vacates.',
        12.9820, 77.5870,
        500.00, 2, 'open',
        CURRENT_DATE + INTERVAL '2 days',
        CURRENT_DATE + INTERVAL '2 days'
    ),

    -- j5: open, Loading & Moving, e3
    (
        'aaaaaaaa-0005-0000-0000-000000000000',
        'eeeeeeee-3333-3333-3333-333333333333',
        (SELECT id FROM categories WHERE name = 'Loading & Moving'),
        'Warehouse Loading Shift',
        'Load and unload goods at a warehouse in Peenya Industrial Area. Heavy lifting involved.',
        12.9555, 77.6140,
        700.00, 5, 'open',
        CURRENT_DATE + INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '3 days'
    ),

    -- j6: open, Delivery, e3
    (
        'aaaaaaaa-0006-0000-0000-000000000000',
        'eeeeeeee-3333-3333-3333-333333333333',
        (SELECT id FROM categories WHERE name = 'Delivery'),
        'Last-mile Delivery Runner',
        'Deliver parcels by foot or bicycle in central Bangalore. Must know local streets.',
        12.9716, 77.5946,
        650.00, 3, 'open',
        CURRENT_DATE + INTERVAL '0 days',
        CURRENT_DATE + INTERVAL '4 days'
    ),

    -- j7: assigned, Construction, e1
    (
        'aaaaaaaa-0007-0000-0000-000000000000',
        'eeeeeeee-1111-1111-1111-111111111111',
        (SELECT id FROM categories WHERE name = 'Construction'),
        'Painter – Interior Walls',
        'Interior painting of a newly constructed apartment complex. Two coats required.',
        12.9720, 77.6000,
        800.00, 2, 'assigned',
        CURRENT_DATE - INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '7 days'
    ),

    -- j8: assigned, Cleaning, e2
    (
        'aaaaaaaa-0008-0000-0000-000000000000',
        'eeeeeeee-2222-2222-2222-222222222222',
        (SELECT id FROM categories WHERE name = 'Cleaning'),
        'Hotel Housekeeping (weekly)',
        'Daily housekeeping for a 40-room hotel in Indiranagar for one week.',
        12.9660, 77.5980,
        520.00, 3, 'assigned',
        CURRENT_DATE - INTERVAL '2 days',
        CURRENT_DATE + INTERVAL '5 days'
    ),

    -- j9: in_progress, Loading & Moving, e3
    (
        'aaaaaaaa-0009-0000-0000-000000000000',
        'eeeeeeee-3333-3333-3333-333333333333',
        (SELECT id FROM categories WHERE name = 'Loading & Moving'),
        'Furniture Relocation – Whitefield',
        'Help relocate office furniture from Indiranagar to Whitefield. Van provided.',
        12.9698, 77.7499,
        750.00, 2, 'in_progress',
        CURRENT_DATE - INTERVAL '3 days',
        CURRENT_DATE + INTERVAL '1 day'
    ),

    -- j10: completed, Construction, e1
    (
        'aaaaaaaa-0010-0000-0000-000000000000',
        'eeeeeeee-1111-1111-1111-111111111111',
        (SELECT id FROM categories WHERE name = 'Construction'),
        'Foundation Digging – HSR Layout',
        'Manual digging for residential building foundation. Tools provided on site.',
        12.9116, 77.6473,
        850.00, 3, 'completed',
        CURRENT_DATE - INTERVAL '10 days',
        CURRENT_DATE - INTERVAL '5 days'
    ),

    -- j11: completed, Cleaning, e2
    (
        'aaaaaaaa-0011-0000-0000-000000000000',
        'eeeeeeee-2222-2222-2222-222222222222',
        (SELECT id FROM categories WHERE name = 'Cleaning'),
        'Post-event Cleaning – Koramangala',
        'Clean up after a large corporate event at a Koramangala venue.',
        12.9352, 77.6245,
        600.00, 2, 'completed',
        CURRENT_DATE - INTERVAL '7 days',
        CURRENT_DATE - INTERVAL '6 days'
    ),

    -- j12: cancelled, Driving, e3
    (
        'aaaaaaaa-0012-0000-0000-000000000000',
        'eeeeeeee-3333-3333-3333-333333333333',
        (SELECT id FROM categories WHERE name = 'Driving'),
        'Airport Pickup Driver',
        'Drive clients from Kempegowda International Airport to city hotels. Own vehicle required.',
        12.9716, 77.5946,
        1200.00, 1, 'cancelled',
        CURRENT_DATE + INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '1 day'
    );


-- =============================================================================
-- 5. APPLICATIONS  (~16 rows)
--    UNIQUE constraint: (job_id, worker_id)
--    workers_assigned is NOT set manually — sync_workers_assigned trigger handles it.
--
--    Accepted applications summary (must not exceed workers_needed):
--      j7 (workers_needed=2): w5 accepted → workers_assigned = 1  ✓
--      j8 (workers_needed=3): w2 accepted → workers_assigned = 1  ✓
--      j10 (workers_needed=3): w1 accepted → workers_assigned = 1  ✓
--      j11 (workers_needed=2): w2 accepted → workers_assigned = 1  ✓
-- =============================================================================

INSERT INTO applications (id, job_id, worker_id, status) VALUES

    -- j1 (open, 3 needed): w1, w2, w3 pending
    ('bbbbbbbb-0001-0000-0000-000000000000',
        'aaaaaaaa-0001-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'pending'),
    ('bbbbbbbb-0002-0000-0000-000000000000',
        'aaaaaaaa-0001-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'pending'),
    ('bbbbbbbb-0003-0000-0000-000000000000',
        'aaaaaaaa-0001-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'pending'),

    -- j2 (open, 2 needed): w4, w5 pending
    ('bbbbbbbb-0004-0000-0000-000000000000',
        'aaaaaaaa-0002-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444', 'pending'),
    ('bbbbbbbb-0005-0000-0000-000000000000',
        'aaaaaaaa-0002-0000-0000-000000000000', '55555555-5555-5555-5555-555555555555', 'pending'),

    -- j3 (open, 4 needed): w2 pending
    ('bbbbbbbb-0006-0000-0000-000000000000',
        'aaaaaaaa-0003-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'pending'),

    -- j4 (open, 2 needed): w2 pending
    ('bbbbbbbb-0007-0000-0000-000000000000',
        'aaaaaaaa-0004-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'pending'),

    -- j5 (open, 5 needed): w3, w1 pending
    ('bbbbbbbb-0008-0000-0000-000000000000',
        'aaaaaaaa-0005-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'pending'),
    ('bbbbbbbb-0009-0000-0000-000000000000',
        'aaaaaaaa-0005-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'pending'),

    -- j6 (open, 3 needed): w4 pending
    ('bbbbbbbb-0010-0000-0000-000000000000',
        'aaaaaaaa-0006-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444', 'pending'),

    -- j7 (assigned, 2 needed): w5 accepted, w1 rejected
    ('bbbbbbbb-0011-0000-0000-000000000000',
        'aaaaaaaa-0007-0000-0000-000000000000', '55555555-5555-5555-5555-555555555555', 'accepted'),
    ('bbbbbbbb-0012-0000-0000-000000000000',
        'aaaaaaaa-0007-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'rejected'),

    -- j8 (assigned, 3 needed): w2 accepted, w3 rejected
    ('bbbbbbbb-0013-0000-0000-000000000000',
        'aaaaaaaa-0008-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'accepted'),
    ('bbbbbbbb-0014-0000-0000-000000000000',
        'aaaaaaaa-0008-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333', 'rejected'),

    -- j10 (completed, 3 needed): w1 accepted
    ('bbbbbbbb-0015-0000-0000-000000000000',
        'aaaaaaaa-0010-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'accepted'),

    -- j11 (completed, 2 needed): w2 accepted
    ('bbbbbbbb-0016-0000-0000-000000000000',
        'aaaaaaaa-0011-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222', 'accepted');


-- =============================================================================
-- 6. REVIEWS  (4 rows — only for completed jobs j10 and j11)
--    UNIQUE constraint: (reviewer_id, job_id) — no duplicate reviewer per job.
--    rating_avg and total_reviews are NOT set — recalculate_rating trigger handles them.
--
--    Expected trigger outcomes after these inserts:
--      w1 (worker): 1 review → rating_avg = 5.00
--      e1 (employer): 1 review → rating_avg = 4.00
--      w2 (worker): 1 review → rating_avg = 4.00
--      e2 (employer): 1 review → rating_avg = 5.00
-- =============================================================================

INSERT INTO reviews (reviewer_id, reviewee_id, job_id, rating, comment) VALUES

    -- j10: e1 reviews w1
    (
        'eeeeeeee-1111-1111-1111-111111111111',
        '11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-0010-0000-0000-000000000000',
        5,
        'Excellent worker, very punctual and skilled'
    ),

    -- j10: w1 reviews e1
    (
        '11111111-1111-1111-1111-111111111111',
        'eeeeeeee-1111-1111-1111-111111111111',
        'aaaaaaaa-0010-0000-0000-000000000000',
        4,
        'Good employer, paid on time'
    ),

    -- j11: e2 reviews w2
    (
        'eeeeeeee-2222-2222-2222-222222222222',
        '22222222-2222-2222-2222-222222222222',
        'aaaaaaaa-0011-0000-0000-000000000000',
        4,
        'Thorough cleaning, would hire again'
    ),

    -- j11: w2 reviews e2
    (
        '22222222-2222-2222-2222-222222222222',
        'eeeeeeee-2222-2222-2222-222222222222',
        'aaaaaaaa-0011-0000-0000-000000000000',
        5,
        'Professional and fair employer'
    );


-- =============================================================================
-- 7. NOTIFICATIONS  (6 rows — varied types, spread across workers and employers)
-- =============================================================================

INSERT INTO notifications (user_id, type, is_read, data) VALUES

    -- w1: told their j7 application was accepted
    (
        '11111111-1111-1111-1111-111111111111',
        'application_accepted',
        false,
        '{"job_id": "aaaaaaaa-0007-0000-0000-000000000000", "job_title": "Painter \u2013 Interior Walls"}'
    ),

    -- w2: told their j8 application was accepted
    (
        '22222222-2222-2222-2222-222222222222',
        'application_accepted',
        false,
        '{"job_id": "aaaaaaaa-0008-0000-0000-000000000000", "job_title": "Hotel Housekeeping (weekly)"}'
    ),

    -- e1: received applications for j1
    (
        'eeeeeeee-1111-1111-1111-111111111111',
        'application_received',
        true,
        '{"job_id": "aaaaaaaa-0001-0000-0000-000000000000", "applicant_count": 3}'
    ),

    -- e1: received a review on j10
    (
        'eeeeeeee-1111-1111-1111-111111111111',
        'review_received',
        false,
        '{"job_id": "aaaaaaaa-0010-0000-0000-000000000000", "rating": 4}'
    ),

    -- w1: received a review on j10
    (
        '11111111-1111-1111-1111-111111111111',
        'review_received',
        false,
        '{"job_id": "aaaaaaaa-0010-0000-0000-000000000000", "rating": 5}'
    ),

    -- e2: received applications for j3
    (
        'eeeeeeee-2222-2222-2222-222222222222',
        'application_received',
        true,
        '{"job_id": "aaaaaaaa-0003-0000-0000-000000000000", "applicant_count": 1}'
    );
