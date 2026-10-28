{% docs table__encounter_diets %}
A diet associated with an encounter.

A patient can be placed on a diet for various medical purposes.
Diets are specified in reference data.
{% enddocs %}

{% docs encounter_diets__encounter_id %}
Reference to the [encounter](#!/source/source.tamanu.tamanu.encounters) this diet is for.
{% enddocs %}

{% docs encounter_diets__diet_id %}
The diet ([Reference Data](#!/source/source.tamanu.tamanu.reference_data), `type = diet`).
{% enddocs %}

{% docs encounter_diets__created_datetime %}
When the diet was added to the encounter in Tamanu, in the deployment's local time.

The diet carries no start or end date of its own, so this is the closest record of when the patient was put on it. It is when the record was created, which may not match the moment the diet was clinically started.
{% enddocs %}
