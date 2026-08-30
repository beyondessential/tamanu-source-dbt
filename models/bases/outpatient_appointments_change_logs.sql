-- One row per appointment change event, from logs.changes.
-- Unfiltered: outpatient_appointments_dataset needs every appointment's creator
-- (change_sequence = 1), so this cannot be date-scoped. BL-031.
{{ outpatient_appointments_change_log_events() }}
