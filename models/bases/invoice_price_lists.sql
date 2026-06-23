select
    id,
    name,
    code,
    rules,
    evaluation_order,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    visibility_status
from {{ source('tamanu', 'invoice_price_lists') }}
where deleted_at is null
