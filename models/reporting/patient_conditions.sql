SELECT
    id,
    recorded_date AS recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id AS recorded_by_id,
    resolved AS is_resolved,
    resolution_date AS resolved_datetime,
    resolution_practitioner_id AS resolved_by_id,
    resolution_note
FROM {{ source("tamanu", "patient_conditions") }}
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
