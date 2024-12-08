select
    ip.id,
    ip.invoice_id,
    ip.date::date as date,
    ip.receipt_number,
    ip.amount,
    ip.updated_by_user_id as updated_by_id
from {{ source("tamanu", "invoice_payments") }} ip
join {{ source("tamanu", "invoices") }} i on i.id = ip.invoice_id
join {{ source("tamanu", "encounters") }} e on e.id = i.encounter_id
where ip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
