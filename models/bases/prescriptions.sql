select
    p.id,
    p.date::timestamp as datetime,
    p.start_date::timestamp as start_datetime,
    p.end_date::timestamp as end_datetime,
    p.medication_id,
    p.prescriber_id,
    p.indication,
    p.route,
    p.quantity,
    p.repeats,
    p.is_ongoing,
    p.is_prn,
    p.is_variable_dose,
    p.dose_amount,
    p.units,
    p.frequency,
    p.duration_value,
    p.duration_unit,
    p.is_phone_order,
    p.ideal_times,
    p.discontinued as is_discontinued,
    p.discontinuing_clinician_id as discontinued_by_id,
    p.discontinuing_reason,
    p.discontinued_date::timestamp as discontinued_datetime
from {{ source('tamanu', 'prescriptions') }} p
-- a prescription belongs to a live patient other than the test patient through an encounter
-- prescription or through a patient ongoing prescription -- the one an ongoing medication added
-- from the patient's record, or carried past its originating encounter, has
where p.deleted_at is null
    and (
        exists (
            select 1
            from {{ source('tamanu', 'encounter_prescriptions') }} ep
            join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
            where ep.prescription_id = p.id
                and ep.deleted_at is null
                and e.deleted_at is null
                and e.patient_id != '{{ var("test_patient") }}'
        )
        or exists (
            select 1
            from {{ source('tamanu', 'patient_ongoing_prescriptions') }} pop
            join {{ source('tamanu', 'patients') }} pt on pt.id = pop.patient_id
            where pop.prescription_id = p.id
                and pop.deleted_at is null
                and pt.deleted_at is null
                and pop.patient_id != '{{ var("test_patient") }}'
        )
    )
