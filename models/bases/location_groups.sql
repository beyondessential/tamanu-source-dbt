{{ incremental_from_table(
    key='id',
    table='location_groups'
) }}
select
    id,
    code,
    name,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'location_groups') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
