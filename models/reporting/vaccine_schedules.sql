SELECT
    id,
    category,
    vaccine_id,
    label,
    dose_label,
    index,
    weeks_from_birth_due,
    weeks_from_last_vaccination_due,
    visibility_status
FROM {{ source("tamanu", "scheduled_vaccines") }}
WHERE deleted_at IS NULL
