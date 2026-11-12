{{ incremental_from_table(
    key='id',
    table='invoice_insurance_plans'
) }}
select
    id,
    name,
    code,
    default_coverage,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'invoice_insurance_plans') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
