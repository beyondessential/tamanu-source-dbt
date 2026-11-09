{{ incremental_config(
    key='id',
    source='logs__tamanu.accesses',
    source_type='table'
) }}
select
    id,
    user_id,
    record_id as patient_id,
    facility_id,
    logged_at at time zone '{{ var("timezone") }}' as logged_at,
    session_id,
    device_id,
    is_mobile,
    version,
    front_end_context,
    back_end_context,
    updated_at_sync_tick
from {{ source("logs__tamanu", "accesses") }}
where deleted_at is null
    and record_type = 'Patient'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
