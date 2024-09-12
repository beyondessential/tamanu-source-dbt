SELECT
    id,
    code,
    name,
    survey_type,
    is_sensitive,
    notifiable AS is_notifiable,
    notify_email_addresses,
    program_id,
    visibility_status
FROM {{ source("tamanu", "surveys") }}
WHERE deleted_at IS NULL
