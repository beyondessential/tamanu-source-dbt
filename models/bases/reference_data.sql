select
    id,
    code,
    name,
    type,
    visibility_status,
    available_facilities
from {{ source('tamanu', 'reference_data') }}
where deleted_at is null
