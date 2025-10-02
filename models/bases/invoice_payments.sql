select
    ip.id,
    ip.invoice_id,
    ip.date::date as date,
    ip.receipt_number,
    ip.amount,
    ip.updated_by_user_id as updated_by_id
from {{ resolve_input_model('invoice_payments') }} ip
join {{ resolve_input_model('invoices') }} i on i.id = ip.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
