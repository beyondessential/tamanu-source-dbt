select
    md.id,
    md.pharmacy_order_prescription_id,
    md.quantity,
    md.dispensed_at::timestamp as dispensed_at,
    md.dispensed_by_user_id
from {{ resolve_input_model('medication_dispenses') }} md
join {{ resolve_input_model('pharmacy_order_prescriptions') }} pop
    on pop.id = md.pharmacy_order_prescription_id
join {{ resolve_input_model('pharmacy_orders') }} po on po.id = pop.pharmacy_order_id
join {{ resolve_input_model('encounters') }} e on e.id = po.encounter_id
where md.deleted_at is null
    and pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
