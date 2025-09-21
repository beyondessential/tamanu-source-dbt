select
    ed.id,
    ed.date::timestamp as datetime,
    ed.is_primary,
    ed.certainty,
    ed.encounter_id,
    ed.diagnosis_id,
    ed.clinician_id as diagnosed_by_id
from {{ resolve_input_model('encounter_diagnoses', source_type=var('base_model_source_type', 'source')) }} ed
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and ed.certainty not in ('disproven', 'error')
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
