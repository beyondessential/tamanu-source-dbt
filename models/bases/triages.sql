select
    t.id,
    t.arrival_time::timestamp as arrival_datetime,
    t.triage_time::timestamp as triage_datetime,
    t.closed_time::timestamp as closed_datetime,
    t.arrival_mode_id,
    t.score,
    t.encounter_id,
    t.practitioner_id as clinician_id,
    t.chief_complaint_id,
    t.secondary_complaint_id
from {{ source('tamanu', 'triages') }} t
join {{ source('tamanu', 'encounters') }} e on e.id = t.encounter_id
where t.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
