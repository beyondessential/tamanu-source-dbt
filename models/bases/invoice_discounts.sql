select
    id.id,
    id.applied_time::timestamp as datetime,
    id.invoice_id,
    id.percentage,
    id.reason,
    id.is_manual,
    id.applied_by_user_id as applied_by_id
from {{ resolve_input_model('invoice_discounts') }} id
join {{ resolve_input_model('invoices') }} i on i.id = id.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where id.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
