{{ incremental_from_table(
    key='id',
    table='program_registries'
) }}
select
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id,
    updated_at_sync_tick
from {{ source('tamanu', 'program_registries') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
