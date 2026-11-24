{{ incremental_from_table(
    key='id',
    table='invoice_price_list_items'
) }}
select
    id,
    invoice_price_list_id,
    invoice_product_id,
    price,
    is_hidden,
    is_fixed_price,
    updated_at_sync_tick
from {{ source('tamanu', 'invoice_price_list_items') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
