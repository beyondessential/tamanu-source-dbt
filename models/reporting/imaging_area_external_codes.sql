SELECT
    id,
    area_id,
    code,
    description,
    visibility_status
FROM {{ source("tamanu", "imaging_area_external_codes") }}
WHERE deleted_at IS NULL
