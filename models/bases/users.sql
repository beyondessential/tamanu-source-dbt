{{ incremental_from_table(
    key='id',
    table='users'
) }}
select
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'users') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
