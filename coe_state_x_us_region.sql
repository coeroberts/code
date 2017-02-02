Note: time zones are only approximate.  Many states span time zones,
and a few do not use DST.  This is just a start.

-- CREATE TABLE tmp_data_dm.coe_state_x_us_region AS
-- SELECT * FROM (
--           SELECT 'Connecticut' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'Maine' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'Massachusetts' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'New Hampshire' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'Rhode Island' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'Vermont' AS state, 'New England' AS division, 'Northeast' AS region
--     UNION SELECT 'New Jersey' AS state, 'Mid-Atlantic' AS division, 'Northeast' AS region
--     UNION SELECT 'New York' AS state, 'Mid-Atlantic' AS division, 'Northeast' AS region
--     UNION SELECT 'Pennsylvania' AS state, 'Mid-Atlantic' AS division, 'Northeast' AS region
--     UNION SELECT 'Illinois' AS state, 'East North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Indiana' AS state, 'East North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Michigan' AS state, 'East North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Ohio' AS state, 'East North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Wisconsin' AS state, 'East North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Iowa' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Kansas' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Minnesota' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Missouri' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Nebraska' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'North Dakota' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'South Dakota' AS state, 'West North Central' AS division, 'Midwest' AS region
--     UNION SELECT 'Delaware' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Florida' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Georgia' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Maryland' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'North Carolina' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'South Carolina' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Virginia' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Washington D.C.' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'West Virginia' AS state, 'South Atlantic' AS division, 'South' AS region
--     UNION SELECT 'Alabama' AS state, 'East South Central' AS division, 'South' AS region
--     UNION SELECT 'Kentucky' AS state, 'East South Central' AS division, 'South' AS region
--     UNION SELECT 'Mississippi' AS state, 'East South Central' AS division, 'South' AS region
--     UNION SELECT 'Tennessee' AS state, 'East South Central' AS division, 'South' AS region
--     UNION SELECT 'Arkansas' AS state, 'West South Central' AS division, 'South' AS region
--     UNION SELECT 'Louisiana' AS state, 'West South Central' AS division, 'South' AS region
--     UNION SELECT 'Oklahoma' AS state, 'West South Central' AS division, 'South' AS region
--     UNION SELECT 'Texas' AS state, 'West South Central' AS division, 'South' AS region
--     UNION SELECT 'Arizona' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Colorado' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Idaho' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Montana' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Nevada' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'New Mexico' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Utah' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Wyoming' AS state, 'Mountain' AS division, 'West' AS region
--     UNION SELECT 'Alaska' AS state, 'Pacific' AS division, 'West' AS region
--     UNION SELECT 'California' AS state, 'Pacific' AS division, 'West' AS region
--     UNION SELECT 'Hawaii' AS state, 'Pacific' AS division, 'West' AS region
--     UNION SELECT 'Oregon' AS state, 'Pacific' AS division, 'West' AS region
--     UNION SELECT 'Washington' AS state, 'Pacific' AS division, 'West' AS region
-- ) qry

DROP TABLE tmp_data_dm.coe_state_x_us_region;
CREATE TABLE tmp_data_dm.coe_state_x_us_region AS
SELECT * FROM (
          SELECT 'Connecticut' AS state, 'New England' AS division,         'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Maine' AS state, 'New England' AS division,               'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Massachusetts' AS state, 'New England' AS division,       'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'New Hampshire' AS state, 'New England' AS division,       'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Rhode Island' AS state, 'New England' AS division,        'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Vermont' AS state, 'New England' AS division,             'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'New Jersey' AS state, 'Mid-Atlantic' AS division,         'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'New York' AS state, 'Mid-Atlantic' AS division,           'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Pennsylvania' AS state, 'Mid-Atlantic' AS division,       'Northeast' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,     'Consistent' AS time_zone_note
    UNION SELECT 'Illinois' AS state, 'East North Central' AS division,     'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Indiana' AS state, 'East North Central' AS division,      'Midwest' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'Michigan' AS state, 'East North Central' AS division,     'Midwest' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'Ohio' AS state, 'East North Central' AS division,         'Midwest' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Wisconsin' AS state, 'East North Central' AS division,    'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Iowa' AS state, 'West North Central' AS division,         'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Kansas' AS state, 'West North Central' AS division,       'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'Minnesota' AS state, 'West North Central' AS division,    'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Missouri' AS state, 'West North Central' AS division,     'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Consistent' AS time_zone_note
    UNION SELECT 'Nebraska' AS state, 'West North Central' AS division,     'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'North Dakota' AS state, 'West North Central' AS division, 'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'South Dakota' AS state, 'West North Central' AS division, 'Midwest' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,       'Some is to the West' AS time_zone_note
    UNION SELECT 'Delaware' AS state, 'South Atlantic' AS division,         'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Florida' AS state, 'South Atlantic' AS division,          'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Some is to the West' AS time_zone_note
    UNION SELECT 'Georgia' AS state, 'South Atlantic' AS division,          'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Maryland' AS state, 'South Atlantic' AS division,         'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'North Carolina' AS state, 'South Atlantic' AS division,   'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'South Carolina' AS state, 'South Atlantic' AS division,   'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Virginia' AS state, 'South Atlantic' AS division,         'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Washington D.C.' AS state, 'South Atlantic' AS division,  'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'West Virginia' AS state, 'South Atlantic' AS division,    'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Alabama' AS state, 'East South Central' AS division,      'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Kentucky' AS state, 'East South Central' AS division,     'South' AS region, 'Eastern Standard Time' AS time_zone_approx, 'EST' AS time_zone_short, 3 AS time_zone_offset_approx,         'Some is to the West' AS time_zone_note
    UNION SELECT 'Mississippi' AS state, 'East South Central' AS division,  'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Tennessee' AS state, 'East South Central' AS division,    'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Some is to the East' AS time_zone_note
    UNION SELECT 'Arkansas' AS state, 'West South Central' AS division,     'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Louisiana' AS state, 'West South Central' AS division,    'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Oklahoma' AS state, 'West South Central' AS division,     'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Texas' AS state, 'West South Central' AS division,        'South' AS region, 'Central Standard Time' AS time_zone_approx, 'CST' AS time_zone_short, 2 AS time_zone_offset_approx,         'Some is to the West' AS time_zone_note
    UNION SELECT 'Arizona' AS state, 'Mountain' AS division,                'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'No DST' As time_zone_note
    UNION SELECT 'Colorado' AS state, 'Mountain' AS division,               'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Idaho' AS state, 'Mountain' AS division,                  'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Some is to the West' AS time_zone_note
    UNION SELECT 'Montana' AS state, 'Mountain' AS division,                'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Nevada' AS state, 'Mountain' AS division,                 'West' AS region, 'Pacific Standard Time' AS time_zone_approx, 'PST' AS time_zone_short, 0 AS time_zone_offset_approx,          'Some is to the East' AS time_zone_note
    UNION SELECT 'New Mexico' AS state, 'Mountain' AS division,             'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Utah' AS state, 'Mountain' AS division,                   'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Wyoming' AS state, 'Mountain' AS division,                'West' AS region, 'Mountain Standard Time' AS time_zone_approx, 'MST' AS time_zone_short, 1 AS time_zone_offset_approx,         'Consistent' AS time_zone_note
    UNION SELECT 'Alaska' AS state, 'Pacific' AS division,                  'West' AS region, 'Alaska Standard Time' AS time_zone_approx, 'AKST' AS time_zone_short, -1 AS time_zone_offset_approx,         'Some is to the West' AS time_zone_note
    UNION SELECT 'California' AS state, 'Pacific' AS division,              'West' AS region, 'Pacific Standard Time' AS time_zone_approx, 'PST' AS time_zone_short, 0 AS time_zone_offset_approx,          'Consistent' AS time_zone_note
    UNION SELECT 'Hawaii' AS state, 'Pacific' AS division,                  'West' AS region, 'Hawaii-Aleutian Standard Time' AS time_zone_approx, 'HST' AS time_zone_short, -2 AS time_zone_offset_approx, 'No DST' As time_zone_note
    UNION SELECT 'Oregon' AS state, 'Pacific' AS division,                  'West' AS region, 'Pacific Standard Time' AS time_zone_approx, 'PST' AS time_zone_short, 0 AS time_zone_offset_approx,          'Some is to the East' AS time_zone_note
    UNION SELECT 'Washington' AS state, 'Pacific' AS division,              'West' AS region, 'Pacific Standard Time' AS time_zone_approx, 'PST' AS time_zone_short, 0 AS time_zone_offset_approx,          'Consistent' AS time_zone_note
) qry
