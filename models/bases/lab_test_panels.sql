{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='lab_test_panels',
    source_type='table'
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
