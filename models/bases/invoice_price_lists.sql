select
    id,
    name,
    code,
    visibility_status
from {{ source('tamanu', 'invoice_price_lists') }}
where deleted_at is null
