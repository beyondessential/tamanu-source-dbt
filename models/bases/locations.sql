select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
from {{ source("tamanu", "locations") }}
where deleted_at is null
