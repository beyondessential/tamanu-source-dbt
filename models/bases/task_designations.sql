select
    id,
    task_id,
    designation_id
from {{ source('tamanu', 'task_designations') }}
where deleted_at is null
