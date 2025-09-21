select
    id,
    name
from {{ resolve_input_model('roles', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
