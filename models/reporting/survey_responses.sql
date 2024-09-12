SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    result_text,
    notified AS is_notified,
    survey_id,
    encounter_id,
    user_id AS submitted_by_id
FROM {{ source("tamanu", "survey_responses") }}
WHERE deleted_at IS NULL
