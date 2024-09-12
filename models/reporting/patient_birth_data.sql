SELECT
    id,
    RIGHT(time_of_birth, 8) AS birth_time,
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
FROM {{ source("tamanu", "patient_birth_data") }}
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
