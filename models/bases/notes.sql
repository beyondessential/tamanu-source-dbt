-- May include notes for the test patient.
select
    n.id,
    n.date::timestamp as datetime,
    n.content,
    n.note_type_id,
    rd.code as note_type,
    n.record_type,
    n.record_id,
    n.author_id as authored_by_id,
    n.on_behalf_of_id,
    n.revised_by_id as updated_note_id,
    n.visibility_status
from {{ resolve_input_model('notes') }} n
join {{ resolve_input_model('reference_data') }} rd
    on rd.id = n.note_type_id
where n.deleted_at is null
