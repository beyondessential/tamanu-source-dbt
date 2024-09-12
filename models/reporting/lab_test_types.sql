SELECT
    id,
    code,
    name,
    unit,
    male_min,
    male_max,
    female_min,
    female_max,
    range_text
    result_type,
    options,
    lab_test_category_id,
    visibility_status
FROM {{ source("tamanu", "lab_test_types") }}
WHERE deleted_at IS NULL
