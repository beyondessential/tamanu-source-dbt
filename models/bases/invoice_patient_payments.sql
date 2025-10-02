select
    ipp.id,
    ipp.invoice_payment_id,
    ipp.method_id
from {{ resolve_input_model('invoice_patient_payments') }} ipp
join {{ resolve_input_model('invoice_payments') }} ip on ip.id = ipp.invoice_payment_id
join {{ resolve_input_model('invoices') }} i on i.id = ip.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where ipp.deleted_at is null
    and ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
