select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    patient_id,
    clinician_id,
    encounter_id,
    location_id,
    booking_type_id,
    is_high_priority,
    status
from {{ source('tamanu', 'appointments') }}
where booking_type_id notnull
    and deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
