select
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status,
    created_at::timestamp as created_datetime
from {{ resolve_input_model('users') }}
where deleted_at is null
