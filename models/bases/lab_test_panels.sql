{{ incremental_from_table(
    key='id',
    table='lab_test_panels'
) }}
select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status,
    available_facilities,
    updated_at_sync_tick
from {{ source('tamanu', 'lab_test_panels') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
