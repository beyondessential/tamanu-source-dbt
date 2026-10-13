select
    id,
    user_id,
    facility_id
from {{ source('tamanu', 'user_facilities') }}
where deleted_at is null
