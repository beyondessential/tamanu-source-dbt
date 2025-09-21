select
    id,
    area_id,
    code,
    description,
    visibility_status
from {{ resolve_input_model('imaging_area_external_codes', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
