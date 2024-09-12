SELECT
    id,
    arrival_time AS arrival_datetime,
    triage_time AS triage_datetime,
    closed_time AS closed_datetime,
    score,
    encounter_id,
    practitioner_id AS clinician_id,
    chief_complaint_id,
    secondary_complaint_id
FROM {{ source("tamanu", "triages") }}
WHERE deleted_at IS NULL
