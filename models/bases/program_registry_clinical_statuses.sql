{{ incremental_from_table(
    key='id',
    table='program_registry_clinical_statuses'
) }}
select
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id,
    updated_at_sync_tick
from {{ source('tamanu', 'program_registry_clinical_statuses') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
