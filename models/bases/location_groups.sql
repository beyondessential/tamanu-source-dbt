select
    id,
    code,
    name,
    facility_id,
    visibility_status
from {{ resolve_input_model('location_groups', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
