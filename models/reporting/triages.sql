SELECT
    id,
    arrival_time::timestamp AS arrival_datetime,
    triage_time::timestamp AS triage_datetime,
    closed_time::timestamp AS closed_datetime,
    arrival_mode_id,
    score,
    encounter_id,
    practitioner_id AS clinician_id,
    chief_complaint_id,
    secondary_complaint_id
FROM {{ source("tamanu", "triages") }}
WHERE deleted_at IS NULL
