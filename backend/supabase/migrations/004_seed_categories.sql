INSERT INTO categories (name, icon_name) VALUES
    ('Construction',     'construction'),
    ('Cleaning',         'cleaning_services'),
    ('Loading & Moving', 'local_shipping'),
    ('Agriculture',      'agriculture'),
    ('Security',         'security'),
    ('Delivery',         'delivery_dining'),
    ('Cooking',          'restaurant'),
    ('Painting',         'format_paint'),
    ('Plumbing',         'plumbing'),
    ('Electrical',       'electrical_services'),
    ('Driving',          'drive_eta'),
    ('General Labour',   'handyman')
ON CONFLICT (name) DO NOTHING;
