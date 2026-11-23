{{ incremental_from_table(
    key='id',
    table='invoice_price_lists'
) }}
select
    id,
    name,
    code,
    rules,
    evaluation_order,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'invoice_price_lists') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
