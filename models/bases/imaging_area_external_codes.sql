{{ incremental_config(
    key='id',
    source='imaging_area_external_codes',
    source_type='table'
) }}
select
    id,
    area_id,
    code,
    description,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'imaging_area_external_codes') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
