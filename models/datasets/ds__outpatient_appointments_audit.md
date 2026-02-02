{% docs ds__outpatient_appointments_audit__change_number %}
Sequential change number for this appointment. 1 = first modification, 2 = second modification, etc.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__is_cancelled %}
Whether the appointment status is 'Cancelled'. Values: Yes/No.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__repeating_end_date %}
Current repeating appointment end date from appointment_schedules.until_date. Only populated if the appointment is part of a repeating schedule.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__is_repeating %}
Whether the appointment is part of a repeating schedule. Values: Yes/No.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__prev_repeating_end_date %}
Previous repeating appointment end date from appointment_schedules.until_date. Only shown if the repeating schedule changed. Blank if unchanged or not applicable.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__prev_is_repeating %}
Whether the previous appointment was part of a repeating schedule. Values: Yes/No. Only shown if the repeating status changed. Blank if unchanged or not applicable.
{% enddocs %}
