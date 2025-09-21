select
    id,
    code,
    name,
    type,
    visibility_status
from {{ resolve_input_model('reference_data', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
