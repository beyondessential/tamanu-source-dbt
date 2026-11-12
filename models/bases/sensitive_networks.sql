{{ incremental_from_table(
    key='id',
    table='sensitive_networks'
) }}
select
    id,
    code,
    name,
    updated_at_sync_tick
from {{ source('tamanu', 'sensitive_networks') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
