select
    id,
    name
from {{ source("tamanu", "roles") }}
where deleted_at is null
