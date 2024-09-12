SELECT
    id,
    code,
    name,
    visibility_status
FROM {{ source("tamanu", "location_groups") }}
WHERE deleted_at IS NULL
