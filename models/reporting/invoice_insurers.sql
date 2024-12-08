select
    ii.id,
    ii.invoice_id,
    ii.insurer_id,
    ii.percentage
from {{ source("tamanu", "invoice_insurers") }} ii
join {{ source("tamanu", "invoices") }} i on i.id = ii.invoice_id
join {{ source("tamanu", "encounters") }} e on e.id = i.encounter_id
where ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
