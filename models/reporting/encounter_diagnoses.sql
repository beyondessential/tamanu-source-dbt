SELECT
    id,
    date AS datetime,
    is_primary,
    certainty,
    encounter_id,
    diagnosis_id,
    clinician_id AS diagnosed_by_id
FROM {{ source("tamanu", "encounter_diagnoses") }}
WHERE deleted_at IS NULL
    AND certainty NOT IN ('disproven', 'error')
