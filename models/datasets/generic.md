{% docs generic__department %}
Full readable name of the department
{% enddocs %}

{% docs generic__departments %}
A comma separated list of names of the departments
{% enddocs %}

{% docs generic__department_id %}
Reference to the [department](#!/source/tamanu-source-dbt.tamanu.departments)
{% enddocs %}

{% docs generic__department_ids %}
An array referencing the [department](#!/source/tamanu-source-dbt.tamanu.departments)
{% enddocs %}

{% docs generic__datetimes %}
A comma separated list of dates and times
{% enddocs %}

{% docs generic__diagnoses %}
Full list of diagnoses
{% enddocs %}

{% docs generic__medications %}
Full list of medications
{% enddocs %}

{% docs generic__vaccinations %}
Full list of vaccinations
{% enddocs %}

{% docs generic__procedures %}
Full list of procedures
{% enddocs %}

{% docs generic__lab_requests %}
Full list of lab requests
{% enddocs %}

{% docs generic__imaging_requests %}
Full list of imaging requests
{% enddocs %}

{% docs generic__notes %}
Full list of notes (cropped if exceeds 32,000 characters)
{% enddocs %}

{% docs generic__encounter_types %}
Full list of encounter types an encounter has been
{% enddocs %}

{% docs generic__duration %}
Duration
{% enddocs %}

{% docs generic__facility %}
Full readable name of the facility
{% enddocs %}

{% docs generic__facility_id %}
Reference to the [facility](#!/source/tamanu-source-dbt.tamanu.facilities)
{% enddocs %}

{% docs generic__insurance_policy_number %}
Insurance policy number of the patient.
{% enddocs %}

{% docs generic__insurers %}
List of insurers covering the patient.
{% enddocs %}

{% docs generic__invoice_remaining_patient_balance %}
Remaining balance to be paid by the patient.
{% enddocs %}

{% docs generic__invoice_total_amount_paid %}
Total amount paid.
{% enddocs %}

{% docs generic__invoice_total_insurer_amount %}
Total amount covered by insurers.
{% enddocs %}

{% docs generic__invoice_total_invoice_amount %}
Total invoicing amount.
{% enddocs %}

{% docs generic__invoice_total_patient_amount %}
Total amount payable by the patient.
{% enddocs %}

{% docs generic__invoice_total_patient_discount %}
Total discount applied to the patient.
{% enddocs %}

{% docs generic__location %}
Full readable name of the location
{% enddocs %}

{% docs generic__location_group %}
Full readable name of the location group
{% enddocs %}

{% docs generic__location_groups %}
A comma separated list of names of the location groups
{% enddocs %}

{% docs generic__location_group_id %}
Reference to the [group](#!/source/tamanu-source-dbt.tamanu.location_groups)
{% enddocs %}

{% docs generic__location_group_ids %}
An array referencing the [group](#!/source/tamanu-source-dbt.tamanu.location_groups)
{% enddocs %}

{% docs generic__location_id %}
Reference to the [location](#!/source/tamanu-source-dbt.tamanu.locations)
{% enddocs %}

{% docs generic__location_ids %}
An array referencing the [location](#!/source/tamanu-source-dbt.tamanu.locations)
{% enddocs %}

{% docs generic__locations %}
A comma separated list of names of the locations
{% enddocs %}

{% docs generic__non_sensitive_tests %}
Full list of non-sensitive tests
{% enddocs %}

{% docs generic__patient_conditions %}
Full list of conditions
{% enddocs %}

{% docs generic__patient_is_deceased %}
Indicates whether the patient has been deceased.
{% enddocs %}

{% docs generic__patient_is_discharged %}
Indicates whether the patient has been discharged.
{% enddocs %}

{% docs generic__patients_age %}
Patient's age
{% enddocs %}

{% docs generic__patients_name %}
Patient Name
{% enddocs %}

{% docs generic__reference_data %}
Full readable name
{% enddocs %}

{% docs generic__sensitive_tests %}
Full list of sensitive tests
{% enddocs %}

{% docs generic__social_security_number %}
Social security number of the patient.
{% enddocs %}

{% docs generic__user_id %}
Reference to the [user](#!/source/tamanu-source-dbt.tamanu.users)
{% enddocs %}


{% docs generic__user %}
Display identifier for the user
{% enddocs %}

{% docs generic__admission_status %}
The current status of the admission.

- `active` indicates the patient is currently admitted
- `discharged` indicates the patient has been discharged
{% enddocs %}

{% docs generic__length_of_stay %}
Length of stay in days for the encounter (null if encounter is still active)
{% enddocs %}

{% docs generic__triage_wait_time %}
Time between triage and being seen (HH:MM:SS format)
{% enddocs %}


