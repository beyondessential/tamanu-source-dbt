SELECT
    id,
    display_id,
    requested_date AS datetime,
    status,
    priority,
    imaging_type,
    encounter_id,
    requested_by_id,
    location_group_id,
    reason_for_cancellation
FROM {{ source("tamanu", "imaging_requests") }}
WHERE deleted_at IS NULL
