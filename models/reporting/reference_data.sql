SELECT
    id,
    code,
    name,
    type,
    visibility_status
FROM {{ source("tamanu", "reference_data") }}
WHERE deleted_at IS NULL
