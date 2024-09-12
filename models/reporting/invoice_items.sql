SELECT
    id,
    invoice_id,
    order_date AS date,
    product_id,
    product_code,
    note,
    product_discountable,
    quantity,
    product_price,
    ordered_by_user_id AS ordered_by_id,
    source_id
FROM {{ source("tamanu", "invoice_items") }}
WHERE deleted_at IS NULL
