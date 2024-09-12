SELECT
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id
FROM {{ source("tamanu", "program_registries") }}
WHERE deleted_at IS NULL
