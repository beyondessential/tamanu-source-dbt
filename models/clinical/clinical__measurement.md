{% docs clinical__measurement %}
OMOP-lite MEASUREMENT domain: one row per clinical measurement, unioning vitals (Tamanu
Vitals survey; the deprecated vitals table is now survey responses) and completed lab-test
results. Numeric results populate value_as_number; categorical results keep
value_source_value. Carries the Tamanu measurement as the source value with
person/visit/provider foreign keys. measurement_concept_id (LOINC) and categorical result
concepts are deferred to the future vocab__ layer. Deployment-specific measurements are
added by per-deployment override.
{% enddocs %}

{% docs clinical__measurement__unit_source_value %}
The unit of measure as recorded in Tamanu (from the lab test type). NULL for vitals, whose
units are implicit in the vital type and not stored per answer.
{% enddocs %}

{% docs clinical__measurement__measurement_id %}
Unique identifier for the measurement; the OMOP measurement_id (the survey_response_answers
id).
{% enddocs %}

{% docs clinical__measurement__visit_occurrence_id %}
The encounter the vital was recorded on; the OMOP visit_occurrence_id. FK to
clinical__visit_occurrence.
{% enddocs %}

{% docs clinical__measurement__measurement_date %}
Date component of the measurement datetime.
{% enddocs %}

{% docs clinical__measurement__measurement_datetime %}
Timestamp at which the measurement was taken — the Vitals survey response start time, or
for labs the test completed time (falling back to the request's published/requested time).
{% enddocs %}

{% docs clinical__measurement__measurement_type_source_value %}
Provenance of the measurement: 'vitals survey' (Vitals survey answer), 'lab' (lab-test
result), or 'birth data' (birth anthropometry from patient_birth_data). Deployment-specific
sources carry their own values when added by override.
{% enddocs %}

{% docs clinical__measurement__value_as_number %}
The measured value as a number, when the vital is numeric. NULL for categorical vitals
(e.g. AVPU) — read value_source_value in that case.
{% enddocs %}

{% docs clinical__measurement__value_source_value %}
The recorded value as entered in Tamanu, retained verbatim. Always populated (numeric or
categorical); the canonical value for categorical vitals until a result concept is mapped.
{% enddocs %}

{% docs clinical__measurement__provider_id %}
The user associated with the measurement — the vitals survey submitter, or the lab
request's requesting clinician. FK to ref__provider.
{% enddocs %}

{% docs clinical__measurement__measurement_source_value %}
The Tamanu measurement type's code — the vital's program-data-element code (e.g. systolic
blood pressure) or the lab test type's code.
{% enddocs %}

{% docs clinical__measurement__measurement_source_name %}
The measurement type's readable name (program-data-element or lab-test-type name),
denormalised alongside the code.
{% enddocs %}
