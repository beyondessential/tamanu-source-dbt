{{ incremental_from_table(
    key='id',
    table='user_facilities'
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
