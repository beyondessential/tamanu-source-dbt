select
    id,
    invoice_payment_id,
    method_id
from {{ source('tamanu', 'invoice_patient_payments') }}
where deleted_at is null
