SELECT
    id,
    date::timestamp AS datetime,
    program_registry_condition_id,
    patient_id,
    program_registry_id,
    clinician_id AS recorded_by_id,
    deletion_date::timestamp AS deleted_datetime,
    deletion_clinician_id AS deleted_by_id
FROM {{ source("tamanu", "patient_program_registration_conditions") }}
WHERE deleted_at IS NULL
    AND patient_id != '{{ var("test_patient") }}'
