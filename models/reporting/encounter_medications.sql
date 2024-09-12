SELECT
    id,
    date AS start_datetime,
    end_date AS end_datetime,
    prescription,
    note,
    indication,
    route,
    qty_morning,
    qty_lunch,
    qty_evening,
    qty_night,
    encounter_id,
    medication_id,
    prescriber_id AS prescribed_by_id,
    quantity,
    repeats,
    is_discharge AS is_discharged,
    discontinued AS is_discontinued,
    discontinued_date,
    discontinuing_reason,
    discontinuing_clinician_id AS discontinued_by_id
FROM {{ source("tamanu", "encounter_medications") }}
WHERE deleted_at IS NULL
