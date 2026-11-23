{{ incremental_from_table(
    key='id',
    table='patient_field_values'
) }}
select
    id,
    patient_id,
    definition_id,
    value,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_field_values') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
