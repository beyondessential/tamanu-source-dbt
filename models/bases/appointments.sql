select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    patient_id,
    clinician_id,
    encounter_id,
    location_id,
    location_group_id,
    type_legacy,
    booking_type_id,
    appointment_type_id,
    is_high_priority,
    status
from {{ source("tamanu", "appointments") }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
