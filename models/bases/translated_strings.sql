select
    string_id,
    language,
    text
from {{ source('tamanu', 'translated_strings') }}
where deleted_at is null
