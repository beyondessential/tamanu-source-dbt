select
    id,
    name,
    code,
    default_coverage,
    visibility_status
from {{ resolve_input_model('invoice_insurance_plans') }}
where deleted_at is null
