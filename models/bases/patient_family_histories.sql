select
    id,
    recorded_date::timestamp as recorded_datetime,
    patient_id,
    practitioner_id as clinician_id,
    diagnosis_id,
    relationship,
    note
from {{ source('tamanu', 'patient_family_histories') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
