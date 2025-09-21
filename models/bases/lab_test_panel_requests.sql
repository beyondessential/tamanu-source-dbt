select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id
from {{ resolve_input_model('lab_test_panel_requests', source_type=var('base_model_source_type', 'source')) }} ltpr
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
