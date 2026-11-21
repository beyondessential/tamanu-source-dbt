select
    iipp.id,
    iipp.invoice_payment_id,
    iipp.invoice_insurance_plan_id,
    iipp.status,
    iipp.reason
from {{ source('tamanu', 'invoice_insurance_plan_payments') }} iipp
join {{ source('tamanu', 'invoice_payments') }} ipay on ipay.id = iipp.invoice_payment_id
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iipp.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
