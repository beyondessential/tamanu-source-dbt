select
    id,
    name,
    code,
    rules,
    visibility_status
from {{ source('tamanu', 'invoice_price_lists') }}
where deleted_at is null
