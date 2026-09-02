{% docs outpatient_appointments_change_logs__change_id %}
Unique identifier for the change log entry (UUID from logs.changes).
{% enddocs %}

{% docs outpatient_appointments_change_logs__appointment_id %}
Reference to the [appointment](#!/model/model.tamanu_source_dbt.outpatient_appointments) that was modified.
{% enddocs %}

{% docs outpatient_appointments_change_logs__modified_datetime %}
Timestamp when the change was logged (from logs.changes.logged_at).
{% enddocs %}

{% docs outpatient_appointments_change_logs__modified_by_user_id %}
Reference to the [user](#!/model/model.tamanu_source_dbt.users) who made the modification.
{% enddocs %}

{% docs outpatient_appointments_change_logs__created_by_user_id %}
Reference to the [user](#!/model/model.tamanu_source_dbt.users) who originally created the appointment.
{% enddocs %}

{% docs outpatient_appointments_change_logs__patient_id %}
Reference to the [patient](#!/model/model.tamanu_source_dbt.patients) associated with the appointment.
{% enddocs %}

{% docs outpatient_appointments_change_logs__start_datetime %}
Current appointment start date and time (after the change).
{% enddocs %}

{% docs outpatient_appointments_change_logs__end_datetime %}
Current appointment end date and time (after the change).
{% enddocs %}

{% docs outpatient_appointments_change_logs__clinician_id %}
Current [clinician](#!/model/model.tamanu_source_dbt.users) ID (after the change).
{% enddocs %}

{% docs outpatient_appointments_change_logs__location_group_id %}
Current [location group](#!/model/model.tamanu_source_dbt.location_groups)/area ID (after the change).
{% enddocs %}

{% docs outpatient_appointments_change_logs__appointment_type_id %}
Current [appointment type](#!/model/model.tamanu_source_dbt.reference_data) ID (after the change).
{% enddocs %}

{% docs outpatient_appointments_change_logs__is_high_priority %}
Current priority status (after the change). Boolean indicating if the appointment is high priority.
{% enddocs %}

{% docs outpatient_appointments_change_logs__status %}
Current appointment status (after the change).

One of:
- `Confirmed`
- `Arrived`
- `No-show`
- `Cancelled`
{% enddocs %}

{% docs outpatient_appointments_change_logs__schedule_id %}
Current recurring schedule ID (after the change). References appointment_schedules table.
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_start_datetime %}
Previous appointment start date and time (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_end_datetime %}
Previous appointment end date and time (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_clinician_id %}
Previous clinician ID (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_location_group_id %}
Previous location group/area ID (before the change).

Null for creation events (change_sequence = 1). In the audit dataset and report this is
additionally null where the previous area is unchanged, where its facility falls outside the
caller's sensitivity partition, and where the area or its facility has since been
soft-deleted — it resolves through the partitioned join rather than straight off the change
event, so an unresolvable area yields no id.
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_appointment_type_id %}
Previous appointment type ID (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_is_high_priority %}
Previous priority status (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__prev_status %}
Previous appointment status (before the change). Null for creation events (change_sequence = 1).
{% enddocs %}

{% docs outpatient_appointments_change_logs__change_sequence %}
Sequential number of this change for the appointment.
- 1 = initial creation event
- 2+ = subsequent modifications

Uses ROW_NUMBER() partitioned by appointment_id and ordered by logged_at.
{% enddocs %}
