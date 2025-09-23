select
    id,
    code,
    name,
    facility_id,
    visibility_status
from {{ resolve_input_model('location_groups') }}
where deleted_at is null
