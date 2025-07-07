select
    a.id,
    a.start_time::timestamp as start_datetime,
    a.end_time::timestamp as end_datetime,
    a.patient_id,
    a.clinician_id,
    a.encounter_id,
    a.schedule_id,
    a.location_id,
    a.booking_type_id,
    a.is_high_priority,
    a.status
from {{ source("tamanu", "appointments") }} a
where a.booking_type_id notnull
    and a.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'
