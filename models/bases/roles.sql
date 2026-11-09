{{ incremental_config(
    key='id',
    source='roles',
    source_type='table'
) }}
select
    id,
    name,
    updated_at_sync_tick
from {{ source('tamanu', 'roles') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
