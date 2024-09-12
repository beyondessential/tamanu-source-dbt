SELECT
    id,
    invoice_item_id,
    percentage,
    reason
FROM {{ source("tamanu", "invoice_item_discounts") }}
WHERE deleted_at IS NULL
