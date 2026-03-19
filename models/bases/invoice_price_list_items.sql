select
    id,
    invoice_price_list_id,
    invoice_product_id,
    price,
    is_hidden
from {{ resolve_input_model('invoice_price_list_items') }}
where deleted_at is null
