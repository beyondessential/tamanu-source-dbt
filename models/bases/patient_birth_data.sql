select
    patient_id,
    time_of_birth::time as birth_time,
    gestational_age_estimate,
    attendant_at_birth,
    name_of_attendant_at_birth,
    birth_type,
    birth_delivery_type,
    birth_weight,
    birth_length,
    apgar_score_one_minute,
    apgar_score_five_minutes,
    apgar_score_ten_minutes,
    registered_birth_place,
    birth_facility_id
from {{ source("tamanu", "patient_birth_data") }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
