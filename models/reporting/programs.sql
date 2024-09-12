SELECT
    id,
    code,
    name
FROM {{ source("tamanu", "programs") }}
WHERE deleted_at IS NULL
