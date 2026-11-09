{{ incremental_config(
    key='id',
    source='surveys',
    source_type='table'
) }}
select
    id,
    code,
    name,
    survey_type,
    is_sensitive,
    notifiable as is_notifiable,
    notify_email_addresses,
    program_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'surveys') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
