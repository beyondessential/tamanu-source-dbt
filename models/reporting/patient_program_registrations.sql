SELECT
    id,
    date::timestamp AS datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id AS registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    is_most_recent
FROM {{ source("tamanu", "patient_program_registrations") }}
WHERE deleted_at IS NULL
    AND patient_id != '{{ var("test_patient") }}'
