select
    id,
    code,
    name
from {{ source('tamanu', 'sensitive_networks') }}
where deleted_at is null
