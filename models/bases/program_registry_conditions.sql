{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='program_registry_conditions',
    source_type='table'
) }}
select
    id,
    code,
    name,
    visibility_status,
    program_registry_id,
    updated_at_sync_tick
from {{ source('tamanu', 'program_registry_conditions') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
