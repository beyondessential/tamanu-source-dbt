select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from {{ resolve_input_model('program_registry_condition_categories', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
