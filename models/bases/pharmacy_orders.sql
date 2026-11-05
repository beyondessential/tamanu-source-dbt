{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='pharmacy_orders',
    source_type='table'
) }}
select
    po.id,
    po.encounter_id,
    po.ordering_clinician_id,
    po.facility_id,
    po.is_discharge_prescription,
    po.date::timestamp as datetime,
    po.updated_at_sync_tick
from {{ source('tamanu', 'pharmacy_orders') }} po
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and po.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
