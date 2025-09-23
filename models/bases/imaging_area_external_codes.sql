select
    id,
    area_id,
    code,
    description,
    visibility_status
from {{ resolve_input_model('imaging_area_external_codes') }}
where deleted_at is null
