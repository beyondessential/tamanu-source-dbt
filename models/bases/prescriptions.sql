select
    p.id,
    p.date::timestamp as datetime,
    p.start_date::timestamp as start_datetime,
    p.end_date::timestamp as end_datetime,
    p.medication_id,
    p.prescriber_id,
    p.quantity,
    p.discontinued as is_discontinued,
    p.discontinuing_clinician_id as discontinued_by_id,
    p.discontinuing_reason,
    p.discontinued_date::timestamp as discontinued_datetime
from {{ resolve_input_model('prescriptions') }} p
join {{ resolve_input_model('encounter_prescriptions') }} ep
    on ep.prescription_id = p.id
join {{ resolve_input_model('encounters') }} e
    on e.id = ep.encounter_id
where p.deleted_at is null
    and ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
