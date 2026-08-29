-- Thin projection of the appointment change log: the source filters, no window functions.
-- Consumers that need to narrow by date or appointment can filter this and have the
-- predicate reach the scan; the windowed reconstruction lives in
-- outpatient_appointments_change_log_events(), which cannot be filtered that way. BL-037.
select
    c.id,
    c.record_id,
    c.logged_at,
    c.record_updated_at,
    c.updated_by_user_id,
    c.updated_at_sync_tick,
    c.record_data
from {{ source('logs__tamanu', 'changes') }} c
where c.table_name = 'appointments'
    and c.record_deleted_at is null
    and (c.record_data ->> 'appointment_type_id') is not null
    and (c.record_data ->> 'patient_id') != '{{ var("test_patient") }}'
