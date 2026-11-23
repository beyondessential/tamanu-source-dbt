{{ incremental_from_table(
    key='id',
    table='facilities'
) }}
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
    sensitive_network_id,
    updated_at_sync_tick
from {{ source('tamanu', 'facilities') }}
where deleted_at is null
    -- sensitive facilities only. Standard ones are in facilities
    and sensitive_network_id is not null
{%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
