select
    id,
    date::timestamp as datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id as registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    is_most_recent
from {{ source("tamanu", "patient_program_registrations") }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
