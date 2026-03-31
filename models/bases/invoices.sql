select
    i.id,
    i.display_id,
    i.date::timestamp as datetime,
    i.status,
    i.patient_payment_status,
    i.insurer_payment_status,
    i.encounter_id
from {{ source('tamanu', 'invoices') }} i
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
