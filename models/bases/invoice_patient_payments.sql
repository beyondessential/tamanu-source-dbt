select
    ipp.id,
    ipp.invoice_payment_id,
    ipp.method_id
from {{ source('tamanu', 'invoice_patient_payments') }} ipp
join {{ source('tamanu', 'invoice_payments') }} ipay on ipay.id = ipp.invoice_payment_id
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ipp.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
