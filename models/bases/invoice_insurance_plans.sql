select
    id,
    name,
    code,
    default_coverage,
    visibility_status
from {{ source('tamanu', 'invoice_insurance_plans') }}
where deleted_at is null
