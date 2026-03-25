select
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status
from {{ source('tamanu', 'users') }}
where deleted_at is null
