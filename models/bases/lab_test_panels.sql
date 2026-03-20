select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
from {{ source('tamanu', 'lab_test_panels') }}
where deleted_at is null
