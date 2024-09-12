SELECT
    id,
    name,
    price,
    discountable,
    visibility_status
FROM {{ source("tamanu", "invoice_products") }}
WHERE deleted_at IS NULL
