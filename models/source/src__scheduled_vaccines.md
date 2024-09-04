{% docs table__vaccine_schedules %}
List of vaccines and their dose schedules. First dose of a vaccine should use `weeks_from_birth_due` whilst subsequent
doses should use `weeks_from_last_vaccination_due`.
{% enddocs %}

{% docs vaccine_schedules__id %}
Tamanu identifier for vaccine schedules
{% enddocs %}

{% docs vaccine_schedules__category %}
Vaccine category. [Campaign, Catch-up, Other, Routine]
{% enddocs %}

{% docs vaccine_schedules__label %}
Vaccine label (e.g. BCG, Typhoid)
{% enddocs %}

{% docs vaccine_schedules__dose_label %}
Vaccine dose label (e.g. Birth, 6 weeks, Dose 1)
{% enddocs %}

{% docs vaccine_schedules__weeks_from_birth_due %}
Number of weeks from birth the recorded vaccine is due. This field should be used only for the first dose of the 
vaccine. Subsequent doses should use `weeks_from_last_vaccination_due`
{% enddocs %}

{% docs vaccine_schedules__index %}
Index used to sort the same vaccines within the same category but with multiple doses/schedules.
{% enddocs %}
