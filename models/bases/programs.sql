select
    id,
    code,
    name
from {{ resolve_input_model('programs') }}
where deleted_at is null
