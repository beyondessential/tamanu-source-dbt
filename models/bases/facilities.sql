{{ incremental_config(
    key='id',
    source='facilities',
    source_type='table'
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
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
