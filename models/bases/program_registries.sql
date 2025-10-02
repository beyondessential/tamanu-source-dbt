select
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id
from {{ resolve_input_model('program_registries') }}
where deleted_at is null
