{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='program_registries',
    source_type='table'
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
