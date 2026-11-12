{{ incremental_from_table(
    key='id',
    table='invoice_insurance_plan_items'
) }}
select
    id,
    invoice_insurance_plan_id,
    invoice_product_id,
    coverage_value,
    updated_at_sync_tick
from {{ source('tamanu', 'invoice_insurance_plan_items') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
