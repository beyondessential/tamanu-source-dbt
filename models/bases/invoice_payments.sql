select
    ipay.id,
    ipay.invoice_id,
    ipay.date,
    ipay.receipt_number,
    ipay.amount
from {{ source('tamanu', 'invoice_payments') }} ipay
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
