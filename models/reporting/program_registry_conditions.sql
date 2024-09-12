SELECT
    id,
    code,
    name,
    visibility_status,
    program_registry_id
FROM {{ source("tamanu", "program_registry_conditions") }}
WHERE deleted_at IS NULL
