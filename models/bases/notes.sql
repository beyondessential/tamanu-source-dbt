-- May include notes for the test patient.
select
    id,
    date::timestamp as datetime,
    content,
    note_type,
    record_type,
    record_id,
    author_id as authored_by_id,
    on_behalf_of_id,
    revised_by_id as updated_note_id,
    visibility_status
from {{ resolve_input_model('notes') }}
where deleted_at is null
