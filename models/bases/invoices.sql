select
    i.id,
    i.display_id,
    i.date::timestamp as datetime,
    i.status,
    i.patient_payment_status,
    i.insurer_payment_status,
    i.encounter_id
from {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
