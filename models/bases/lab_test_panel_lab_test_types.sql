{{ incremental_from_table(
    key='id',
    table='lab_test_panel_lab_test_types'
) }}
select
    id,
    lab_test_panel_id,
    lab_test_type_id,
    updated_at_sync_tick
from {{ source('tamanu', 'lab_test_panel_lab_test_types') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
