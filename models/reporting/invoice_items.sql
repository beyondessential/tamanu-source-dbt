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
from {{ source("tamanu", "invoice_items") }} ii
join {{ source("tamanu", "invoices") }} i on i.id = ii.invoice_id
join {{ source("tamanu", "encounters") }} e on e.id = i.encounter_id
where ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
