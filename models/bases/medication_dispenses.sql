{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='medication_dispenses',
    source_type='table'
) }}
select
    md.id,
    md.pharmacy_order_prescription_id,
    md.quantity,
    md.dispensed_at::timestamp as dispensed_at,
    md.dispensed_by_user_id,
    md.medication_id,
    md.route,
    md.updated_at_sync_tick
from {{ source('tamanu', 'medication_dispenses') }} md
join {{ source('tamanu', 'pharmacy_order_prescriptions') }} pop
    on pop.id = md.pharmacy_order_prescription_id
join {{ source('tamanu', 'pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where md.deleted_at is null
    and pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and md.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
