{{ incremental_config(
    key='id',
    source='departments',
    source_type='table'
) }}
select
    id,
    code,
    name,
    facility_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'departments') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
