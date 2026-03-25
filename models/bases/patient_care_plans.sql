select
    id,
    date::timestamp as care_plan_datetime,
    patient_id,
    examiner_id as clinician_id,
    care_plan_id
from {{ source('tamanu', 'patient_care_plans') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
