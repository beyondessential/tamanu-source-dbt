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
    deactivated_clinician_id as deactivated_by_id,
    deactivated_date::timestamp as deactivated_datetime
from {{ resolve_input_model('patient_program_registrations', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
