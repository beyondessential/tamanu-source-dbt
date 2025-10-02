select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id
from {{ resolve_input_model('lab_test_panel_requests') }} ltpr
join {{ resolve_input_model('encounters') }} e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
