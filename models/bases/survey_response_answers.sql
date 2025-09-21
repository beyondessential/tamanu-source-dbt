select
    id,
    name,
    body,
    response_id,
    data_element_id
from {{ resolve_input_model('survey_response_answers', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
