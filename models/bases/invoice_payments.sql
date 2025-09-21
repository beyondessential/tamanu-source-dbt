select
    ip.id,
    ip.invoice_id,
    ip.date::date as date,
    ip.receipt_number,
    ip.amount,
    ip.updated_by_user_id as updated_by_id
from {{ resolve_input_model('invoice_payments', source_type=var('base_model_source_type', 'source')) }} ip
join {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i on i.id = ip.invoice_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
