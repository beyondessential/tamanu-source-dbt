select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from {{ source("tamanu", "program_registry_condition_categories") }}
where deleted_at is null
