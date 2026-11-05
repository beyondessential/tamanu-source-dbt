{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='pharmacy_order_prescriptions',
    source_type='table'
) }}
select
    pop.id,
    pop.pharmacy_order_id,
    pop.prescription_id,
    pop.ongoing_prescription_id,
    pop.display_id,
    pop.quantity,
    pop.repeats,
    pop.is_completed,
    pop.updated_at_sync_tick
from {{ source('tamanu', 'pharmacy_order_prescriptions') }} pop
join {{ source('tamanu', 'pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and pop.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
