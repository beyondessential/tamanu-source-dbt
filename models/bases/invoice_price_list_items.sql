select
    id,
    invoice_price_list_id,
    invoice_product_id,
    price,
    is_hidden,
    is_fixed_price
from {{ source('tamanu', 'invoice_price_list_items') }}
where deleted_at is null
