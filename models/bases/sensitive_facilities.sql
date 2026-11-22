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
    visibility_status,
    sensitive_network_id
from {{ source('tamanu', 'facilities') }}
where deleted_at is null
    -- sensitive facilities only. Standard ones are in facilities
    and sensitive_network_id is not null
