select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
from {{ resolve_input_model('lab_test_panels') }}
where deleted_at is null
