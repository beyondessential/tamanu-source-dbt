{{ incremental_config(
    key='id',
    source='reference_data',
    source_type='table'
) }}
select
    id,
    code,
    name,
    type,
    visibility_status,
    available_facilities,
    updated_at_sync_tick
from {{ source('tamanu', 'reference_data') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
