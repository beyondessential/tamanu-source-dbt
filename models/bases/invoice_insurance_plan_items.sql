select
    id,
    invoice_insurance_plan_id,
    invoice_product_id,
    coverage_value
from {{ resolve_input_model('invoice_insurance_plan_items') }}
where deleted_at is null
