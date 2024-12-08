select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    patient_id,
    clinician_id,
    location_id,
    location_group_id,
    type,
    status
from {{ source("tamanu", "appointments") }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
