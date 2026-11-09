{{ incremental_config(
    key='id',
    source='survey_responses',
    source_type='table'
) }}
select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    result_text,
    notified as is_notified,
    survey_id,
    encounter_id,
    user_id as submitted_by_id,
    updated_at_sync_tick
from {{ source('tamanu', 'survey_responses') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
