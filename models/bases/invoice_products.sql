select
    id,
    name,
    category,
    insurable,
    visibility_status,
    source_record_type,
    source_record_id
from {{ resolve_input_model('invoice_products') }}
where deleted_at is null
