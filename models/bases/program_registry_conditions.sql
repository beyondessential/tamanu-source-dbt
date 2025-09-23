select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from {{ resolve_input_model('program_registry_conditions') }}
where deleted_at is null
