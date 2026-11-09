{{ incremental_config(
    key='id',
    source='task_designations',
    source_type='table'
) }}
select
    id,
    task_id,
    designation_id,
    updated_at_sync_tick
from {{ source('tamanu', 'task_designations') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
