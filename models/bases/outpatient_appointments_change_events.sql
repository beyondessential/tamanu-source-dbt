-- BL-037: thin projection of the appointment change log -- source filters, no window
-- functions, so consumers can filter it and have the predicate reach the scan. The windowed
-- reconstruction lives in outpatient_appointments_change_log_events(), which cannot be
-- filtered that way.
select
    c.id,
    c.record_id,
    c.logged_at,
    c.record_updated_at,
    c.updated_by_user_id,
    c.updated_at_sync_tick,
    c.record_data
from {{ source('logs__tamanu', 'changes') }} c
-- BL-037: the change-log source filters. A row is excluded where the appointment was
-- already flagged deleted when that row was written -- see BL-035 case 4
where c.table_name = 'appointments'
    and c.record_deleted_at is null
    and (c.record_data ->> 'appointment_type_id') is not null
    and (c.record_data ->> 'patient_id') != '{{ var("test_patient") }}'
