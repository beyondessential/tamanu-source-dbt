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
    -- discontinued_date is varchar(255) -- Tamanu's dateTimeString -- so it can hold text
    -- that is not a date. A bare cast aborts the entire model when it does, and only on a
    -- target where the consuming clinical/ models materialise as tables (analytics): a view
    -- never evaluates the cast, which is why release builds stayed green while an analytics
    -- build failed on the same data. Guard it so malformed text yields null rather than
    -- taking the build down. A genuinely discontinued prescription is identified by
    -- is_discontinued, not by this column, so nulling unparseable text loses no signal.
    case
        when p.discontinued_date ~ '^\d{4}-\d{2}-\d{2}([ T]\d{2}:\d{2}:\d{2})?$'
            then p.discontinued_date::timestamp
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
