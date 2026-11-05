{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='invoice_products',
    source_type='table'
) }}
select
    id,
    name,
    insurable,
    category,
    source_record_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'invoice_products') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
