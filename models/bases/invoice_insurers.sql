select
    ii.id,
    ii.invoice_id,
    ii.insurer_id,
    ii.percentage
from {{ resolve_input_model('invoice_insurers') }} ii
join {{ resolve_input_model('invoices') }} i on i.id = ii.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
