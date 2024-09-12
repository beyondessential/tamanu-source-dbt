SELECT
    id,
    imaging_request_id,
    area_id
FROM {{ source("tamanu", "imaging_request_areas") }}
WHERE deleted_at IS NULL
