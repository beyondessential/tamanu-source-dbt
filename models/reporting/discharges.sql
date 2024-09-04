SELECT
    id,
    note,
    encounter_id,
    discharger_id,
    disposition_id
FROM {{ source("tamanu", "discharges") }}
WHERE deleted_at IS NULL
