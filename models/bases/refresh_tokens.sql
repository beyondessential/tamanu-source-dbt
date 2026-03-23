select
    id,
    device_id,
    user_id,
    expires_at,
    created_at,
    updated_at
from
    {{ source('tamanu', 'refresh_tokens') }}
where deleted_at is null
