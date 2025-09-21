select
    patient_id,
    definition_id,
    value
from {{ resolve_input_model('patient_field_values', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
