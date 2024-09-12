SELECT
    id,
    completed_at AS datetime,
    description,
    imaging_request_id,
    external_code,
    completed_by_id,
    visibility_status
FROM {{ source("tamanu", "imaging_results") }}
WHERE deleted_at IS NULL
