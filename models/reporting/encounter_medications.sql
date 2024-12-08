select
    em.id,
    em.date::timestamp as start_datetime,
    em.end_date::timestamp as end_datetime,
    em.prescription,
    em.note,
    em.indication,
    em.route,
    em.qty_morning,
    em.qty_lunch,
    em.qty_evening,
    em.qty_night,
    em.encounter_id,
    em.medication_id,
    em.prescriber_id as prescribed_by_id,
    em.quantity,
    em.repeats,
    em.is_discharge as is_discharged,
    em.discontinued as is_discontinued,
    em.discontinued_date::date as discontinued_date,
    em.discontinuing_reason,
    em.discontinuing_clinician_id as discontinued_by_id
from {{ source("tamanu", "encounter_medications") }} em
join {{ source("tamanu", "encounters") }} e on e.id = em.encounter_id
where em.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
