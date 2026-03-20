select
    pop.id,
    pop.pharmacy_order_id,
    pop.prescription_id,
    pop.display_id,
    pop.quantity,
    pop.repeats,
    pop.is_completed
from {{ resolve_input_model('pharmacy_order_prescriptions') }} pop
join {{ resolve_input_model('pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ resolve_input_model('encounters') }} e on e.id = po.encounter_id
where pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
