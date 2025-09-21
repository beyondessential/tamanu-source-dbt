select
    eh.id,
    eh.date::timestamp as datetime,
    eh.encounter_id,
    eh.department_id,
    eh.location_id,
    eh.encounter_type,
    eh.examiner_id as clinician_id,
    eh.actor_id as updated_by_id,
    eh.change_type
from {{ resolve_input_model('encounter_history', source_type=var('base_model_source_type', 'source')) }} eh
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = eh.encounter_id
where eh.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
