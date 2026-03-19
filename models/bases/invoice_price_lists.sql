select
    id,
    name,
    code,
    visibility_status
from {{ resolve_input_model('invoice_price_lists') }}
where deleted_at is null
