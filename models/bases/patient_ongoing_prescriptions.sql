select
    pop.id,
    pop.patient_id,
    pop.prescription_id
from {{ source('tamanu', 'patient_ongoing_prescriptions') }} pop
where pop.deleted_at is null
    and pop.patient_id != '{{ var("test_patient") }}'
