select
    id,
    recorded_date::timestamp as recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id as recorded_by_id,
    resolved as is_resolved,
    resolution_date::timestamp as resolved_datetime,
    resolution_practitioner_id as resolved_by_id,
    resolution_note
from {{ resolve_input_model('patient_conditions') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
