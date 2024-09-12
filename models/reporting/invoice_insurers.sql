SELECT
    id,
    invoice_id,
    insurer_id,
    percentage
FROM {{ source("tamanu", "invoice_insurers") }}
WHERE deleted_at IS NULL
