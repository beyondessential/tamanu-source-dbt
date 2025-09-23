select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
from {{ resolve_input_model('locations') }}
where deleted_at is null
