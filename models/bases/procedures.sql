select
    p.id,
    p.date::date as date,
    p.start_time::time as start_time,
    p.end_time::time as end_time,
    p.completed as is_completed,
    p.note,
    p.completed_note,
    p.encounter_id,
    p.location_id,
    p.procedure_type_id,
    p.anaesthetic_id,
    p.physician_id as clinician_id,
    p.assistant_id,
    p.anaesthetist_id
from {{ source("tamanu", "procedures") }} p
join {{ source("tamanu", "encounters") }} e on e.id = p.encounter_id
where p.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
