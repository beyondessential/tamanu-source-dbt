select
    id,
    area_id,
    code,
    description,
    visibility_status
from {{ source("tamanu", "imaging_area_external_codes") }}
where deleted_at is null
