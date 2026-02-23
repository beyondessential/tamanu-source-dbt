select
    id,
    created_at,
    patient_id,
    facility_id
from {{ resolve_input_model('patient_facilities') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'