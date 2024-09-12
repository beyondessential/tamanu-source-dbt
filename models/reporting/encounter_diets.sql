SELECT
    id,
    encounter_id,
    diet_id
FROM {{ source("tamanu", "encounter_diets") }}
WHERE deleted_at IS NULL
