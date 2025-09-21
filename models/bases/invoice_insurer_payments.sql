select
    iip.id,
    iip.invoice_payment_id,
    iip.insurer_id,
    iip.status,
    iip.reason
from {{ resolve_input_model('invoice_insurer_payments', source_type=var('base_model_source_type', 'source')) }} iip
join {{ resolve_input_model('invoice_payments', source_type=var('base_model_source_type', 'source')) }} ip on ip.id = iip.invoice_payment_id
join {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i on i.id = ip.invoice_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where iip.deleted_at is null
    and ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
