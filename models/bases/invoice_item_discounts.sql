select
    iid.id,
    iid.invoice_item_id,
    iid.amount,
    iid.type,
    iid.reason
from {{ resolve_input_model('invoice_item_discounts') }} iid
join {{ resolve_input_model('invoice_items') }} ii on ii.id = iid.invoice_item_id
join {{ resolve_input_model('invoices') }} i on i.id = ii.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where iid.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
