SELECT
    id,
    invoice_payment_id,
    method_id
FROM {{ source("tamanu", "invoice_patient_payments") }}
WHERE deleted_at IS NULL
