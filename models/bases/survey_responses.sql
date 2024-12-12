select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    result_text,
    notified as is_notified,
    survey_id,
    encounter_id,
    user_id as submitted_by_id
from {{ source("tamanu", "survey_responses") }}
where deleted_at is null
