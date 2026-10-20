select
    d.id,
    d.mar_id,
    mar.prescription_id,
    ep.encounter_id,
    d.given_time::timestamp as given_at,
    d.dose_amount
from {{ source('tamanu', 'medication_administration_record_doses') }} d
join {{ source('tamanu', 'medication_administration_records') }} mar on mar.id = d.mar_id
join {{ source('tamanu', 'encounter_prescriptions') }} ep on ep.prescription_id = mar.prescription_id
join {{ source('tamanu', 'encounters') }} e on e.id = ep.encounter_id
where d.deleted_at is null
    and mar.deleted_at is null
    and ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    -- a dose counts as given only on a given administration that was not flagged as an error
    -- and whose dose was not removed. Compared case-insensitively: the source documents GIVEN
    -- but the data carries 'given'.
    and lower(mar.status::text) = 'given'
    and coalesce(mar.is_error, false) = false
    and coalesce(d.is_removed, false) = false
    and d.given_time is not null
