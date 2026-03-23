select
    id,
    code,
    name,
    type,
    visibility_status
from {{ source('tamanu', 'reference_data') }}
where deleted_at is null
