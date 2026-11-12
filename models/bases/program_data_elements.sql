{{ incremental_from_table(
    key='id',
    table='program_data_elements'
) }}
select
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config,
    updated_at_sync_tick
from {{ source('tamanu', 'program_data_elements') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
