SELECT
    id,
    start_date AS start_datetime,
    CASE WHEN end_date < start_date THEN start_date
         ELSE end_date
    END AS end_datetime,
    encounter_type,
    reason_for_encounter,
    device_id,
    patient_id,
    department_id
    location_id,
    examiner_id AS clinician_id,
    patient_billing_type_id,
    referral_source_id,
    planned_location_id,
    planned_location_start_time AS planned_location_start_datetime
FROM {{ source("tamanu", "encounters") }}
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
