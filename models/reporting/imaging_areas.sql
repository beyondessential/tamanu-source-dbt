select
    id,
    imaging_request_id,
    area_id
from {{ source("tamanu", "imaging_request_areas") }}
where deleted_at is null
