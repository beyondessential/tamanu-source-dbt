select
    patient_id,
    definition_id,
    value
from {{ source("tamanu", "patient_field_values") }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
