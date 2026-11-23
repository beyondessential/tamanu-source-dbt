-- One row per appointment change event, from logs.changes.
-- Unfiltered: outpatient_appointments_dataset needs every appointment's creator
-- (change_sequence = 1), so this cannot be date-scoped. BL-031.
{{ incremental_from_logs(
    key='appointment_id',
    table='appointments'
) }}
{{ outpatient_appointments_change_log_events(
    record_id_filter=('c.record_id in (' ~ changed_since_last_run('appointments') ~ ')') if is_incremental() else none
) }}
