select
    id.id,
    id.applied_time::timestamp as datetime,
    id.invoice_id,
    id.percentage,
    id.reason,
    id.is_manual,
    id.applied_by_user_id as applied_by_id
from {{ resolve_input_model('invoice_discounts', source_type=var('base_model_source_type', 'source')) }} id
join {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i on i.id = id.invoice_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where id.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
