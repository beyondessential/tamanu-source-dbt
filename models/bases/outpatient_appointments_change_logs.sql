-- One row per appointment change event, from logs.changes.
-- Unfiltered: the window functions need each appointment's full history to stay correct,
-- so this cannot be date-scoped. BL-031.
--
-- No model ref()s this one any more -- outpatient_appointments_dataset resolved its creator
-- here on change_sequence = 1 until BL-044 moved it to a window-free distinct on over
-- outpatient_appointments_change_events, and the audit report and audit dataset call
-- outpatient_appointments_change_log_events() directly. It is kept as a published reporting
-- view for analytics consumers wanting the reconstructed change history.
{{ outpatient_appointments_change_log_events() }}
