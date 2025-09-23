select
    id,
    code,
    name,
    facility_id,
    visibility_status
from {{ resolve_input_model('departments') }}
where deleted_at is null
