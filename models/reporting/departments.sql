select
    id,
    code,
    name,
    facility_id,
    visibility_status
from {{ source("tamanu", "departments") }}
where deleted_at is null
