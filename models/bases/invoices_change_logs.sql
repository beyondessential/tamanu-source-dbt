select
    c.id as change_id,
    c.record_id as invoice_id,
    c.logged_at,
    c.updated_by_user_id,
    c.record_data ->> 'status' as status,
    c.record_data ->> 'encounter_id' as encounter_id,
    lag(c.record_data ->> 'status') over (
        partition by c.record_id
        order by c.logged_at
    ) as previous_status,
    row_number() over (
        partition by c.record_id
        order by c.logged_at
    ) as change_sequence
from {{ source('logs__tamanu', 'changes') }} c
where
    c.table_name = 'invoices'
    and c.record_deleted_at is null
