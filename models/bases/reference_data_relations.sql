{{ incremental_from_table(
    key='id',
    table='reference_data_relations'
) }}
select
    id,
    reference_data_id,
    reference_data_parent_id,
    type,
    updated_at_sync_tick
from {{ source('tamanu', 'reference_data_relations') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
