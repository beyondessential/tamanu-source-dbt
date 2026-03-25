select
    id,
    name,
    insurable,
    category,
    source_record_id,
    visibility_status
from {{ source('tamanu', 'invoice_products') }}
where deleted_at is null
