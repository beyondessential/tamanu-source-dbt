select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
from {{ resolve_input_model('locations', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
