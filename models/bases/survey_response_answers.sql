select
    id,
    name,
    body,
    response_id,
    data_element_id
from {{ resolve_input_model('survey_response_answers') }}
where deleted_at is null
