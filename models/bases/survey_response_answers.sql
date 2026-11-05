{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='survey_response_answers',
    source_type='table'
) }}
select
    id,
    name,
    body,
    response_id,
    data_element_id,
    updated_at_sync_tick
from {{ source('tamanu', 'survey_response_answers') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
