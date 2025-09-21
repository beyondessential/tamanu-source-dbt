select
    id,
    name,
    price,
    discountable,
    visibility_status
from {{ resolve_input_model('invoice_products', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
