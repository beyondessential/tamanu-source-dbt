select
    pop.id,
    pop.pharmacy_order_id,
    pop.prescription_id,
    pop.ongoing_prescription_id,
    pop.display_id,
    pop.quantity,
    pop.repeats,
    pop.is_completed
from {{ source('tamanu', 'pharmacy_order_prescriptions') }} pop
join {{ source('tamanu', 'pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
