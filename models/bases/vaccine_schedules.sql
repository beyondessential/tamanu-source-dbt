select
    id,
    category,
    vaccine_id,
    label,
    dose_label,
    index,
    weeks_from_birth_due,
    weeks_from_last_vaccination_due,
    sort_index,
    visibility_status
from {{ resolve_input_model('scheduled_vaccines', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
