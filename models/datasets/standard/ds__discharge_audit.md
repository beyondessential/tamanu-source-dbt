{% docs ds__discharge_audit__admission_datetime %}
Start date and time of the encounter being discharged.
{% enddocs %}

{% docs ds__discharge_audit__discharge_datetime_entered %}
The clinical discharge date and time entered on the discharge form. This is the "discharge date" shown on other reports.
{% enddocs %}

{% docs ds__discharge_audit__discharge_recorded_datetime %}
When the discharge was recorded in Tamanu, which is when a user completed the discharge form.

Taken from the discharge change log, so this is blank for discharges predating the change log.
{% enddocs %}

{% docs ds__discharge_audit__days_between_discharge_and_recording %}
Whole days between the discharge date entered on the form and the date the discharge was recorded in Tamanu. Zero means the discharge was recorded on the day it happened.
{% enddocs %}

{% docs ds__discharge_audit__discharger_on_form %}
The clinician named as the discharging clinician on the discharge form. Not necessarily the person who completed the form.
{% enddocs %}

{% docs ds__discharge_audit__recorded_by_user %}
The user who completed the discharge form. Blank where the discharge predates the change log or no user could be attributed to the session.
{% enddocs %}

{% docs ds__discharge_audit__is_auto_discharge %}
Whether Tamanu created the discharge automatically rather than a user completing a discharge form. Automatic discharges are raised by the outpatient and deceased-patient dischargers, and on vaccination and survey completion.
{% enddocs %}

{% docs ds__discharge_audit__later_edit_count %}
Number of times the discharge was edited after it was first recorded. Blank where the discharge predates the change log.
{% enddocs %}
