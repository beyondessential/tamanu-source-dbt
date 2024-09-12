SELECT
    id,
    display_id,
    date AS datetime,
    status,
    patient_payment_status,
    insurer_payment_status,
    encounter_id
FROM {{ source("tamanu", "invoices") }}
WHERE deleted_at IS NULL
