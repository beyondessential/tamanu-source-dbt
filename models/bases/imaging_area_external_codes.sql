{{ incremental_from_table(
    key='id',
    table='imaging_area_external_codes'
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
