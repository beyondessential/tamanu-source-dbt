SELECT
    id,
    display_id,
    first_name,
    middle_name,
    last_name,
    cultural_name,
    email,
    sex,
    date_of_birth,
    date_of_death,
    village_id
FROM {{ source("tamanu", "patients") }}
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    AND visibility_status != 'merged'
