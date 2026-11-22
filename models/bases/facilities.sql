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
    -- standard facilities only. Sensitive ones are in sensitive_facilities
    and sensitive_network_id is null
