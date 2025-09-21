select
    id,
    patient_id,
    allergy_id,
    recorded_date::date as recorded_date,
    practitioner_id as recorded_by
from {{ resolve_input_model('patient_allergies', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
