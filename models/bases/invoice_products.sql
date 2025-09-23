select
    id,
    name,
    price,
    discountable,
    visibility_status
from {{ resolve_input_model('invoice_products') }}
where deleted_at is null
