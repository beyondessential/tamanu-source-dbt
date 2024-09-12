SELECT
    id,
    invoice_payment_id,
    insurer_id,
    status,
    reason
FROM {{ source("tamanu", "invoice_insurer_payments") }}
WHERE deleted_at IS NULL
