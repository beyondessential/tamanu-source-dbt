select
    id,
    invoice_payment_id,
    insurer_id,
    status
from {{ source('tamanu', 'invoice_insurer_payments') }}
where deleted_at is null
