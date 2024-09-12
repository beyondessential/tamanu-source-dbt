SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    completed AS is_completed,
    note,
    completed_note,
    encounter_id,
    location_id,
    procedure_type_id,
    anaesthetic_id,
    physician_id AS clinician_id,
    assistant_id,
    anaesthetist_id
FROM {{ source("tamanu", "procedures") }}
WHERE deleted_at IS NULL
