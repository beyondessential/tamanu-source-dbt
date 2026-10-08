select
    id,
    created_at,
    outcome,
    user_id
from {{ source('tamanu', 'user_login_attempts') }}
where deleted_at is null
