select
    c.id as change_id,
    c.record_id as invoice_id,
    c.logged_at,
    c.updated_by_user_id,
    c.record_data ->> 'status' as status,
    i.encounter_id,
    lag(c.record_data ->> 'status') over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as previous_status,
    row_number() over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as change_sequence
from {{ source('logs__tamanu', 'changes') }} c
join {{ source('tamanu', 'invoices') }} i on i.id = c.record_id
    and i.deleted_at is null
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
where
    c.table_name = 'invoices'
    and c.record_deleted_at is null
