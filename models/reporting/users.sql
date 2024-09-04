SELECT
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status
FROM {{ source("tamanu", "users") }}
WHERE deleted_at IS NULL
