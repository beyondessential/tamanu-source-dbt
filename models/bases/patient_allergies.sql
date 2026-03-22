select
    id,
    patient_id,
    allergy_id,
    recorded_date::date as recorded_date,
    practitioner_id as recorded_by
from {{ source('tamanu', 'patient_allergies') }}
where deleted_at is null
