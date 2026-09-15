select
    iifi.id,
    iifi.invoice_item_id,
    iifi.invoice_insurance_plan_id,
    iifi.coverage_value_final
from {{ source('tamanu', 'invoice_item_finalised_insurances') }} iifi
join {{ source('tamanu', 'invoice_items') }} ii on ii.id = iifi.invoice_item_id
join {{ source('tamanu', 'invoices') }} i on i.id = ii.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iifi.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
