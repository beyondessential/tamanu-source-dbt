select
    id,
    code,
    external_code,
    name,
    unit,
    male_min,
    male_max,
    female_min,
    female_max,
    range_text
    as result_type,
    options,
    lab_test_category_id,
    visibility_status,
    is_sensitive
from {{ resolve_input_model('lab_test_types', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
