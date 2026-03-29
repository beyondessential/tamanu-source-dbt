select
    id,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    patient_id,
    facility_id
from {{ source('tamanu', 'patient_facilities') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'