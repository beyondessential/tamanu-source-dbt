SELECT
    id,
    start_time::timestamp AS start_datetime,
    end_time::timestamp AS end_datetime,
    result_text,
    notified AS is_notified,
    survey_id,
    encounter_id,
    user_id AS submitted_by_id
FROM {{ source("tamanu", "survey_responses") }}
WHERE deleted_at IS NULL
