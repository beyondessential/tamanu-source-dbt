select
    id,
    user_id,
    designation_id
from {{ source('tamanu', 'user_designations') }}
where deleted_at is null
