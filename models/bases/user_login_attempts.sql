{{ incremental_from_table(
    key='id',
    table='user_login_attempts'
) }}
select
    id,
    -- Central-local time, so the report layer's to_user_selected_timezone (which expects a naive
    -- central-time timestamp) and a day bucket both read the login's local day, not its UTC day.
    created_at at time zone '{{ var("timezone") }}' as created_at,
    outcome,
    user_id,
    updated_at_sync_tick
from {{ source('tamanu', 'user_login_attempts') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
