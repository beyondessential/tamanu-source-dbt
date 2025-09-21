select
    ii.id,
    ii.invoice_id,
    ii.order_date::date as date,
    ii.product_id,
    ii.product_code,
    ii.product_name,
    ii.note,
    ii.product_discountable,
    ii.quantity,
    ii.product_price,
    ii.ordered_by_user_id as ordered_by_id,
    ii.source_id
from {{ resolve_input_model('invoice_items', source_type=var('base_model_source_type', 'source')) }} ii
join {{ resolve_input_model('invoices', source_type=var('base_model_source_type', 'source')) }} i on i.id = ii.invoice_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = i.encounter_id
where ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
