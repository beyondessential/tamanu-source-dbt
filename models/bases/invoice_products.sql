select
    id,
    name,
    insurable,
    category,
    source_record_id,
    visibility_status
from {{ resolve_input_model('invoice_products') }}
where deleted_at is null
