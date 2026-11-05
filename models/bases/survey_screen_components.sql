{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='survey_screen_components',
    source_type='table'
) }}
select
    id,
    screen_index,
    component_index,
    text,
    visibility_criteria,
    validation_criteria,
    detail,
    config,
    options,
    calculation,
    survey_id,
    data_element_id,
    visibility_status,
    updated_at_sync_tick
from {{ source('tamanu', 'survey_screen_components') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
