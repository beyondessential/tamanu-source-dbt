select
    p.id as patient_id,
    e.id as encounter_id,
    p.display_id,
    e.end_datetime as discharge_datetime,
    concat(p.first_name, ' ', p.last_name) as patient_name
from {{ ref('encounters') }} e
join {{ ref('patients') }} p
    on p.id = e.patient_id
left join {{ ref('invoices') }} i
    on i.encounter_id = e.id
where e.end_datetime is not null
    and i.id is null
