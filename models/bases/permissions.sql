select
    id,
    role_id,
    verb,
    noun,
    object_id
from {{ source('tamanu', 'permissions') }}
where deleted_at is null
