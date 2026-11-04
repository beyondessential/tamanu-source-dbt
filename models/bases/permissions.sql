{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='permissions',
    source_type='table'
) }}
select
    id,
    role_id,
    verb,
    noun,
    object_id,
    updated_at_sync_tick
from {{ source('tamanu', 'permissions') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
