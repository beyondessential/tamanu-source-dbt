SELECT
    id,
    name,
    body,
    response_id,
    data_element_id
FROM {{ source("tamanu", "survey_response_answers") }}
WHERE deleted_at IS NULL
