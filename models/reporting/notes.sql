SELECT
    id,
    date AS datetime,
    content,
    note_type,
    record_type,
    record_id,
    author_id AS authored_by_id,
    on_behalf_of_id,
    revised_by_id AS updated_note_id,
    visibility_status
FROM {{ source("tamanu", "notes") }}
WHERE deleted_at IS NULL
