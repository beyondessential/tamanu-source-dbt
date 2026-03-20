select
    id,
    code,
    name,
    facility_id,
    visibility_status
from {{ source('tamanu', 'location_groups') }}
where deleted_at is null
