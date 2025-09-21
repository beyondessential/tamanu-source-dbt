select
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id
from {{ resolve_input_model('program_registries', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
