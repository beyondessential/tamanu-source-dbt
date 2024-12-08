select
    iip.id,
    iip.invoice_payment_id,
    iip.insurer_id,
    iip.status,
    iip.reason
from {{ source("tamanu", "invoice_insurer_payments") }} iip
join {{ source("tamanu", "invoice_payments") }} ip on ip.id = iip.invoice_payment_id
join {{ source("tamanu", "invoices") }} i on i.id = ip.invoice_id
join {{ source("tamanu", "encounters") }} e on e.id = i.encounter_id
where iip.deleted_at is null
    and ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
