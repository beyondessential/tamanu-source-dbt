select distinct on (d.encounter_id)
    d.id,
    d.note,
    d.encounter_id,
    d.discharger_id as discharged_by_id,
    d.disposition_id
from {{ resolve_input_model('discharges') }} d
join {{ resolve_input_model('encounters') }} e on e.id = d.encounter_id
where d.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
order by d.encounter_id asc, d.created_at asc
