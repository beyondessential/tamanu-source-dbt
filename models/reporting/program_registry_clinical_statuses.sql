SELECT
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id
FROM {{ source("tamanu", "program_registry_clinical_statuses") }}
WHERE deleted_at IS NULL
