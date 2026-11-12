{{ incremental_from_table(
    key='id',
    table='task_designations'
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
