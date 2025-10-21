select
    p.id,
    p.date::timestamp as datetime,
    p.start_time::timestamp as start_datetime,
    p.end_time::timestamp as end_datetime,
    p.completed as is_completed,
    p.note,
    p.completed_note,
    p.encounter_id,
    p.location_id,
    p.procedure_type_id,
    p.anaesthetic_id,
    p.physician_id as clinician_id,
    p.anaesthetist_id,
    p.assistant_anaesthetist_id,
    p.time_in,
    p.time_out
from {{ resolve_input_model('procedures') }} p
join {{ resolve_input_model('encounters') }} e on e.id = p.encounter_id
where p.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
