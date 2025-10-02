select
    id,
    code,
    name,
    division,
    type,
    email,
    contact_number,
    city_town,
    street_address,
    catchment_id,
    visibility_status
from {{ resolve_input_model('facilities') }}
where deleted_at is null
