select
    id,
    code,
    name
from {{ source('tamanu', 'programs') }}
where deleted_at is null
