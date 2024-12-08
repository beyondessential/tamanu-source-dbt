SELECT
    id,
    recorded_date::timestamp AS recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id AS recorded_by_id,
    resolved AS is_resolved,
    resolution_date::timestamp AS resolved_datetime,
    resolution_practitioner_id AS resolved_by_id,
    resolution_note
FROM {{ source("tamanu", "patient_conditions") }}
WHERE deleted_at IS NULL
    AND patient_id != '{{ var("test_patient") }}'
