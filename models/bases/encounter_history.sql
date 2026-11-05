{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='encounter_history',
    source_type='table'
) }}
select
    eh.id,
    eh.date::timestamp as datetime,
    eh.encounter_id,
    eh.department_id,
    eh.location_id,
    eh.encounter_type,
    eh.examiner_id as clinician_id,
    eh.actor_id as updated_by_id,
    eh.change_type::text[],
    eh.updated_at_sync_tick
from {{ source('tamanu', 'encounter_history') }} eh
join {{ source('tamanu', 'encounters') }} e on e.id = eh.encounter_id
where eh.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and eh.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
