{#
    Ranks a note within its revision chain, 1 being the current revision.

    Tamanu never edits a note in place. Each edit inserts a new row whose revised_by_id
    (bases/notes.updated_note_id) points at the chain's root, and the root keeps its own row.
    Every revision points at the root, not at the revision before it, so
    coalesce(updated_note_id, id) identifies the chain.

        {{ notes__revision_rank('n') }} as revision_rank
        ...
        where revision_rank = 1

    `note_alias` is the alias of a bases/notes row, or of a CTE selecting from it, carrying id,
    updated_note_id, datetime and created_datetime.

    The current revision is the latest by datetime, the order Tamanu's own note list uses.
    datetime is second-precision, so an edit within the same second ties on it and
    created_datetime breaks the tie -- the revision is the later insert. id settles any
    remaining tie so the result is deterministic.

    Rank before filtering on note_type: a revision can change a note's type, so filtering first
    keeps a superseded revision. Filtering on record_type first is safe, since a revision stays
    on its root's record, and keeps the window small.
#}
{% macro notes__revision_rank(note_alias) %}
row_number() over (
    partition by coalesce({{ note_alias }}.updated_note_id, {{ note_alias }}.id)
    order by
        {{ note_alias }}.datetime desc,
        {{ note_alias }}.created_datetime desc,
        {{ note_alias }}.id desc
)
{% endmacro %}
