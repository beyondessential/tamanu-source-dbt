select
    id,
    device_id,
    user_id,
    expires_at,
    created_at,
    updated_at
from
    {{ resolve_input_model('refresh_tokens') }}
where deleted_at is null
