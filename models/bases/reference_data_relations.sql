select
    id,
    reference_data_id,
    reference_data_parent_id,
    type
from {{ source('tamanu', 'reference_data_relations') }}
where deleted_at is null
