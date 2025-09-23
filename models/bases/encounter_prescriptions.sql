select
    ep.id,
    ep.encounter_id,
    ep.prescription_id,
    ep.is_selected_for_discharge
from {{ resolve_input_model('encounter_prescriptions') }} ep
join {{ resolve_input_model('encounters') }} e on e.id = ep.encounter_id
where ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
