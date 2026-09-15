{% docs clinical__condition_occurrence %}
OMOP-lite CONDITION_OCCURRENCE domain: one row per encounter diagnosis, with the Tamanu
ICD-10 diagnosis retained as the source value and the person/visit/provider foreign keys
that anchor it in the OMOP graph. condition_concept_id (standard SNOMED) is deferred to the
future vocab__ layer. Program-registry conditions are a planned second source.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_occurrence_id %}
Unique identifier for the diagnosis; the OMOP condition_occurrence_id (the
encounter_diagnoses id).
{% enddocs %}

{% docs clinical__condition_occurrence__visit_occurrence_id %}
The encounter the diagnosis was recorded on; the OMOP visit_occurrence_id. FK to
clinical__visit_occurrence.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_start_date %}
Date component of the diagnosis datetime.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_start_datetime %}
Timestamp at which the diagnosis was recorded.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_end_date %}
Date the condition resolved. NULL — Tamanu encounter diagnoses are point-in-time and carry
no resolution date.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_end_datetime %}
Timestamp the condition resolved. NULL — as above.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_type_source_value %}
Provenance of the diagnosis. Constant 'encounter diagnosis' for this domain; a future
program-registry source will carry a distinct value.
{% enddocs %}

{% docs clinical__condition_occurrence__condition_status_source_value %}
The diagnosis certainty as recorded in Tamanu (e.g. confirmed, suspected). Disproven and
error certainties are excluded upstream.
{% enddocs %}

{% docs clinical__condition_occurrence__is_primary %}
Whether this was the primary diagnosis on the encounter (vs a secondary diagnosis).
{% enddocs %}

{% docs clinical__condition_occurrence__condition_source_value %}
The diagnosis's ICD-10 code (Tamanu reference-data code).
{% enddocs %}

{% docs clinical__condition_occurrence__condition_source_name %}
The diagnosis's readable name (Tamanu reference-data name), denormalised alongside the code.
{% enddocs %}
