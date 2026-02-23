select
    id,
    created_at,
    patient_id,
    facility_id
from {{ source("tamanu", "patient_facilities") }}
where patient_id != '{{ var("test_patient") }}'
    and deleted_at is null