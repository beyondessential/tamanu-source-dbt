{{ incremental_config(
    key='id',
    source='encounter_prescriptions',
    source_type='table'
) }}
select
    ep.id,
    ep.encounter_id,
    ep.prescription_id,
    ep.is_selected_for_discharge,
    ep.updated_at_sync_tick
from {{ source('tamanu', 'encounter_prescriptions') }} ep
join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
where ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ep.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
