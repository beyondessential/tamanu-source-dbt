SELECT
    id,
    applied_time AS datetime,
    invoice_id,
    percentage,
    reason,
    is_manual,
    applied_by_user_id AS applied_by_id
FROM {{ source("tamanu", "invoice_discounts") }}
WHERE deleted_at IS NULL
