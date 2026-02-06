{% docs ds__outpatient_appointments_audit__change_number %}
Sequential change number for this appointment where initial creation is excluded. 1 = first modification, 2 = second modification, etc.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__is_cancelled %}
Whether the appointment status is 'Cancelled'. Values: Yes/No.
{% enddocs %}

{% docs ds__outpatient_appointments_audit__is_repeating %}
Whether the appointment is part of a repeating schedule. Values: Yes (has schedule_id), No (no schedule_id).
{% enddocs %}
