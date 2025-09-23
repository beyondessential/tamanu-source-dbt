select
    id,
    name
from {{ resolve_input_model('roles') }}
where deleted_at is null
