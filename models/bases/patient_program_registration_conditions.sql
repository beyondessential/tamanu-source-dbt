select
    id,
    date::timestamp as datetime,
    program_registry_condition_id,
    patient_id,
    program_registry_id,
    clinician_id as recorded_by_id,
    deletion_date::timestamp as deleted_datetime,
    deletion_clinician_id as deleted_by_id
from {{ source("tamanu", "patient_program_registration_conditions") }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
