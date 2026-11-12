{{ incremental_from_table(
    key='id',
    table='encounter_diets'
) }}
select
    ed.id,
    ed.encounter_id,
    ed.diet_id,
    ed.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    ed.updated_at_sync_tick
from {{ source('tamanu', 'encounter_diets') }} ed
join {{ source('tamanu', 'encounters') }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ed.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
