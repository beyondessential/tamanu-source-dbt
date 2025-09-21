select
    ed.id,
    ed.encounter_id,
    ed.diet_id
from {{ resolve_input_model('encounter_diets', source_type=var('base_model_source_type', 'source')) }} ed
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ed.encounter_id
where ed.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
