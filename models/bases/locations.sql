{{ incremental_config(
    key='id',
    source='locations',
    source_type='table'
) }}
select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'locations') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
