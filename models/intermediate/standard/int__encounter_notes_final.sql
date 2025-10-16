-- May include notes for the test patient.
with notes_ordering as (
    select
        id,
        datetime,
        content,
        note_type,
        record_type,
        record_id,
        authored_by_id,
        on_behalf_of_id,
        updated_note_id,
        visibility_status,
        row_number() over (partition by coalesce(updated_note_id, id) order by datetime desc) as row_number
    from {{ ref('notes') }}
    where record_type = 'Encounter'
        and note_type != 'system'
)
select 
    id,
    datetime,
    content,
    note_type,
    record_type,
    record_id,
    authored_by_id,
    on_behalf_of_id,
    visibility_status
from notes_ordering
where row_number = 1