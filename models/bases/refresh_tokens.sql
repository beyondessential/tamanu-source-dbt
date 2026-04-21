select
    id,
    device_id,
    user_id,
    expires_at at time zone '{{ var("timezone") }}' as expires_at,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    updated_at at time zone '{{ var("timezone") }}' as updated_at
from
    {{ source('tamanu', 'refresh_tokens') }}
where deleted_at is null
