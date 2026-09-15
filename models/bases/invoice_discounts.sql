select
    id.id,
    id.invoice_id,
    id.percentage,
    id.reason,
    id.is_manual,
    id.applied_by_user_id,
    id.applied_time
from {{ source('tamanu', 'invoice_discounts') }} id
join {{ source('tamanu', 'invoices') }} i on i.id = id.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    id.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
