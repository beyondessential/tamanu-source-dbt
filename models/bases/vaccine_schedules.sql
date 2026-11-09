{{ incremental_config(
    key='id',
    source='scheduled_vaccines',
    source_type='table'
) }}
select
    id,
    category,
    vaccine_id,
    label,
    dose_label,
    index,
    weeks_from_birth_due,
    weeks_from_last_vaccination_due,
    sort_index,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'scheduled_vaccines') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
