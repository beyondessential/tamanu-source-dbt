select
    id,
    lab_test_panel_id,
    lab_test_type_id
from {{ resolve_input_model('lab_test_panel_lab_test_types', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
