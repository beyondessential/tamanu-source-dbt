select
    id,
    code,
    name,
    type,
    visibility_status
from {{ resolve_input_model('reference_data') }}
where deleted_at is null
