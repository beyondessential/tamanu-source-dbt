{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='invoice_insurance_plans',
    source_type='table'
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
