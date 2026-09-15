-- Base model for discharge change logs
-- Extracts discharge record changes from logs.changes
-- Each row represents a change event on a discharge record, ordered by change_sequence

select
    c.id as change_id,
    c.record_id as discharge_id,
    d.encounter_id,
    c.logged_at at time zone '{{ var("timezone") }}' as changed_datetime,
    c.updated_by_user_id as changed_by_user_id,
    c.record_data ->> 'note' as note,
    c.record_data ->> 'discharger_id' as discharger_id,
    c.record_data ->> 'disposition_id' as disposition_id,
    row_number() over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as change_sequence
from {{ source('logs__tamanu', 'changes') }} c
join {{ source('tamanu', 'discharges') }} d
    on d.id = c.record_id
    and d.deleted_at is null
join {{ source('tamanu', 'encounters') }} e
    on e.id = d.encounter_id
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
where
    c.table_name = 'discharges'
    and c.record_deleted_at is null
