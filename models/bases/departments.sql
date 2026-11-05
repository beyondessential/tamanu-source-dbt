{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='departments',
    source_type='table'
) }}
select
    id,
    code,
    name,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'departments') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
