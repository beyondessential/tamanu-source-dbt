select
    po.id,
    po.encounter_id,
    po.ordering_clinician_id,
    po.facility_id,
    po.is_discharge_prescription,
    po.date::timestamp as datetime
from {{ source('tamanu', 'pharmacy_orders') }} po
join {{ source('tamanu', 'encounters') }} e on e.id = po.encounter_id
where po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
