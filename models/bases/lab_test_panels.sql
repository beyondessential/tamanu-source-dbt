select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
from {{ resolve_input_model('lab_test_panels', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
