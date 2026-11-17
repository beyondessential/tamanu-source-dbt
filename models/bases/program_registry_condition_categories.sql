{{ incremental_from_table(
    key='id',
    table='program_registry_condition_categories'
) }}
select
    id,
    code,
    name,
    visibility_status,
    program_registry_id,
    updated_at_sync_tick
from {{ source('tamanu', 'program_registry_condition_categories') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
