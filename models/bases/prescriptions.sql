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
    p.dosing_unit,
    p.dispensing_unit,
    p.unit_conversion,
    p.frequency,
    p.duration_value,
    p.duration_unit,
    p.is_phone_order,
    p.ideal_times,
    p.discontinued as is_discontinued,
    p.discontinuing_clinician_id as discontinued_by_id,
    p.discontinuing_reason,
    -- discontinued_date is a dateTimeString varchar and can hold non-date text, so the cast
    -- is guarded -- unparseable text yields null and is_discontinued remains the signal for
    -- a discontinuation. Prefix-anchored and truncated so a fractional part, a zone offset
    -- or minute precision still parse.
    case
        when p.discontinued_date ~ '^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])'
            then left(p.discontinued_date, 19)::timestamp
    end as discontinued_datetime
from {{ source('tamanu', 'prescriptions') }} p
where p.deleted_at is null
    and exists (
        select 1
        from {{ source('tamanu', 'encounter_prescriptions') }} ep
        join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
        where ep.prescription_id = p.id
            and ep.deleted_at is null
            and e.deleted_at is null
            and e.patient_id != '{{ var("test_patient") }}'
    )
