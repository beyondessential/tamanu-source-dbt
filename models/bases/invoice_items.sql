select
    ii.id,
    ii.invoice_id,
    ii.order_date::date as date,
    ii.product_id,
    ii.product_code_final,
    ii.product_name_final,
    ii.price_final,
    ii.manual_entry_price,
    ii.quantity,
    ii.ordered_by_user_id,
    ii.approved,
    ii.source_record_type,
    ii.source_record_id
from {{ resolve_input_model('invoice_items') }} ii
join {{ resolve_input_model('invoices') }} i on i.id = ii.invoice_id
join {{ resolve_input_model('encounters') }} e on e.id = i.encounter_id
where
    ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
