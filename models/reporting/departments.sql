SELECT
    id,
    code,
    name,
    facility_id,
    visibility_status
FROM {{ source("tamanu", "departments") }}
WHERE deleted_at IS NULL
