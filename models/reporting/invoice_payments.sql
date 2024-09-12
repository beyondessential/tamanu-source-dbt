SELECT
    id,
    invoice_id,
    date,
    receipt_number,
    amount
FROM {{ source("tamanu", "invoice_payments") }}
WHERE deleted_at IS NULL
