{% docs clinical__visit_occurrence %}
OMOP-lite VISIT_OCCURRENCE domain: one row per encounter with OMOP visit-type
concept ID alongside the Tamanu encounter_type source value. Canonical encounter
surface for the clinical layer; visit_occurrence_id is the foreign key carried by
downstream clinical event models.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_concept_id %}
OMOP standard Visit concept ID for the encounter type (9201 Inpatient Visit,
9202 Outpatient Visit, 9203 Emergency Room Visit). NULL when the encounter type
has no corresponding standard concept.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_start_date %}
Date component of the encounter start datetime.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_start_datetime %}
Timestamp at which the encounter began.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_end_date %}
Date component of the encounter end datetime. NULL for open or in-progress encounters.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_end_datetime %}
Timestamp at which the encounter ended. NULL for open or in-progress encounters.
{% enddocs %}

{% docs clinical__visit_occurrence__visit_type_concept_id %}
OMOP concept indicating how the visit was recorded. Always 32817 (EHR administration
record) for Tamanu-sourced encounters.
{% enddocs %}

{% docs clinical__visit_occurrence__care_site_id %}
UUID of the area (location_group) of the encounter's location. FK to
ref__care_site.care_site_id (area-type rows).
{% enddocs %}
