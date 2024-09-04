SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    patient_id,
    clinician_id,
    location_id,
    location_group_id,
    type,
    status
FROM {{ source("tamanu", "appointments") }}
WHERE deleted_at IS NULL
