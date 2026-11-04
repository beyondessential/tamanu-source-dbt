{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='user_facilities',
    source_type='table'
) }}
select
    id,
    user_id,
    facility_id,
    updated_at_sync_tick
from {{ source('tamanu', 'user_facilities') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
