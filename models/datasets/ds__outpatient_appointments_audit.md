{% docs ds__outpatient_appointments_audit__change_number %}
Sequential change number for this appointment. 0 = initial creation, 1 = first modification, 2 = second modification, etc.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__is_cancelled %}
Whether the appointment status is 'Cancelled'. Values: Yes/No.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__repeating_end_date %}
Current repeating appointment end date from appointment_schedules.until_date. Only populated if the appointment is part of a repeating schedule.
{% enddocs %}
