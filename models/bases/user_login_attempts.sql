{{ incremental_from_table(
    key='id',
    table='user_login_attempts'
) }}
select
    id,
    created_at,
    outcome,
    user_id,
    updated_at_sync_tick
from {{ source('tamanu', 'user_login_attempts') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
