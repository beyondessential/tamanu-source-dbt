select
    ii.id,
    ii.invoice_id,
    ii.insurer_id,
    ii.percentage
from {{ resolve_input_model('invoice_insurers', source_type=var('base_model_source_type', 'source')) }} ii
join {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i on i.id = ii.invoice_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
