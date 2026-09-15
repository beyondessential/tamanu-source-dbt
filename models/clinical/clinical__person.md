{% docs clinical__person %}
OMOP-lite PERSON domain: one row per patient with decomposed birth date and OMOP
concept-ID shadow columns alongside local source values. Canonical patient-identity
surface for the clinical layer; person_id is the foreign key carried by every
downstream clinical event.
{% enddocs %}

{% docs clinical__person__person_source_value %}
The patient's display identifier (medical record number). Tagged
`direct_identifier`: masking is applied to the replica, not by dbt, so the
column is populated on every target.
{% enddocs %}

{% docs clinical__person__gender_concept_id %}
OMOP standard Gender concept ID for the patient's sex (8507 Male, 8532 Female).
NULL when the recorded sex has no corresponding standard concept.
{% enddocs %}

{% docs clinical__person__year_of_birth %}
Year component of the patient's date of birth.
{% enddocs %}

{% docs clinical__person__month_of_birth %}
Month component of the patient's date of birth.
{% enddocs %}

{% docs clinical__person__day_of_birth %}
Day component of the patient's date of birth.
{% enddocs %}

{% docs clinical__person__birth_datetime %}
Date of birth combined with the recorded time of birth. NULL when no time of birth
was recorded.
{% enddocs %}

{% docs clinical__person__location_id %}
Reference to the patient's geographic location (their village) in ref__location.
{% enddocs %}
