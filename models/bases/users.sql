select
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status
from {{ resolve_input_model('users', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
