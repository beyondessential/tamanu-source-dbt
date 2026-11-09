{{ incremental_from_table(
    key='id',
    table='permissions'
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
