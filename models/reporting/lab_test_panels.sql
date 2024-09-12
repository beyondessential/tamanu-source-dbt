SELECT
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
FROM {{ source("tamanu", "lab_test_panels") }}
WHERE deleted_at IS NULL
