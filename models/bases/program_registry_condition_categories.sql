{{ incremental_config(
    key='id',
    source='program_registry_condition_categories',
    source_type='table'
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
