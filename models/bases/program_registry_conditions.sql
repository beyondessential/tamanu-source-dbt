select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from {{ source('tamanu', 'program_registry_conditions') }}
where deleted_at is null
