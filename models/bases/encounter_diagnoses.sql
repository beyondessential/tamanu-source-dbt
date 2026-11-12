{{ incremental_from_table(
    key='id',
    table='encounter_diagnoses'
) }}
select
    ed.id,
    ed.date::timestamp as datetime,
    ed.is_primary,
    ed.certainty,
    ed.encounter_id,
    ed.diagnosis_id,
    ed.clinician_id as diagnosed_by_id,
    ed.updated_at_sync_tick
from {{ source('tamanu', 'encounter_diagnoses') }} ed
join {{ source('tamanu', 'encounters') }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and ed.certainty not in ('disproven', 'error')
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ed.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
