select
    id,
    name,
    body,
    response_id,
    data_element_id
from {{ source('tamanu', 'survey_response_answers') }}
where deleted_at is null
