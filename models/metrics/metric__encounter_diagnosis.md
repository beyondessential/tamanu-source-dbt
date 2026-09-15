{% docs metric__encounter_diagnosis %}
D5 metric view for the morbidity indicator registered in documentations/metrics/*.yml:
encounter_diagnosis. One row per recorded diagnosis -- per-diagnosis (subject) grain, so a consumer
aggregates at whatever grain it needs.

A diagnosis is one recorded against a clinical encounter. Diagnoses a clinician later marked
disproven or entered in error are excluded. An encounter with several diagnoses contributes
one row each, so a patient seen twice for the same condition counts twice -- this measures
diagnosis events, not people.

Conditions tracked alongside a program registry enrolment are not counted here. They have no
encounter behind them, so they carry neither a facility nor an encounter type; they are in
clinical__condition_occurrence for a consumer that wants them.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, encounter type, sex, diagnosis, certainty, primary flag -- and over any time grain
from day upwards. Nothing is pre-aggregated, so no dimension has to be collapsed to get a
total.

See specs/dbt-model/metric__encounter_diagnosis.md for BL-001..BL-009.
{% enddocs %}

{% docs metric__encounter_diagnosis__metric_id %}
The registered indicator identifier: always 'encounter_diagnosis'. Joins to the canonical registry in
documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__encounter_diagnosis__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs metric__encounter_diagnosis__subject_id %}
The OMOP condition occurrence id of the diagnosis
(clinical__condition_occurrence.condition_occurrence_id).

One row per diagnosis, so this is unique within the metric -- a consumer needing a distinct
count rather than a sum can use count(distinct subject_id) and get the same answer.

It is a diagnosis id, not a patient id: the row carries no patient identifier, and a patient
with several diagnoses appears once per diagnosis with no way to link them from here. That is
what keeps this model unrestricted.
{% enddocs %}

{% docs metric__encounter_diagnosis__period_start %}
Calendar day the diagnosis was recorded.

Day grain lets a consumer roll up to week, month, quarter or year. No period is withheld --
today's diagnoses are emitted, and a consumer wanting only complete periods excludes the
current one in its own date filter.
{% enddocs %}

{% docs metric__encounter_diagnosis__period_end %}
NULL -- a diagnosis is point-in-time. Tamanu records when a diagnosis was made, not when the
condition resolved, so there is no period to close.
{% enddocs %}

{% docs metric__encounter_diagnosis__period_granularity %}
Constant 'day' -- period_start is a date, not a timestamp.
{% enddocs %}

{% docs metric__encounter_diagnosis__value_numeric %}
Always 1 -- one diagnosis per row.

Sum it to count diagnoses over any grouping: over everything for the facility total, over
nothing extra for the national total. Because it is additive and nothing is pre-aggregated,
no disaggregation has to be collapsed to get a total.
{% enddocs %}

{% docs metric__encounter_diagnosis__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__encounter_diagnosis__encounter_type %}
The type of encounter the diagnosis was recorded against -- emergency, outpatient, admission
and the other types the deployment configures.

Lets one metric split morbidity by setting without a separate metric per setting.

This is the encounter's type as it now stands, not the phase the patient was in when the
diagnosis was recorded -- Tamanu updates the type in place as an encounter progresses, so a
diagnosis made in the emergency department on a patient later admitted reads as `admission`.
Filtering on it answers "diagnoses on encounters that ended as X".
{% enddocs %}

{% docs metric__encounter_diagnosis__diagnosis_code %}
The diagnosis's reference-data code, as recorded. 'Not recorded' where the encounter carries
a diagnosis with no code behind it.

Emitted as recorded, ungrouped. Deployments differ in what this code is -- some record real
ICD-10, others a local code list -- so any classification of it into chapters, blocks or a
national grouping is a deployment choice made downstream, not here.
{% enddocs %}

{% docs metric__encounter_diagnosis__diagnosis %}
The diagnosis's readable name, as recorded, falling back to its code where the name is
missing and to 'Not recorded' where neither is present.

This is the label to rank and chart by. Never NULL, so a consumer filtering on it does not
silently drop the diagnoses it cannot name.
{% enddocs %}

{% docs metric__encounter_diagnosis__diagnosis_certainty %}
How certain the clinician was -- confirmed, suspected and the other values the deployment
configures.

Always populated. Diagnoses marked disproven or entered in error never reach this metric, and
neither do those with no certainty recorded at all, so every value here is one that still
stands.
{% enddocs %}

{% docs metric__encounter_diagnosis__is_primary %}
Whether the diagnosis was the principal one for its encounter, as opposed to a secondary or
comorbid diagnosis. NULL where the encounter did not rank its diagnoses.

Filter to primary diagnoses for a casemix view that counts each encounter once; leave it
unfiltered to count every condition recorded.
{% enddocs %}

{% docs metric__encounter_diagnosis__age_years %}
Age in whole years at the diagnosis date, from the patient's birth date. NULL when the birth
date is missing.

Not banded. An age classification is a presentation choice -- WHO primary bands, five-year
bands, a national HMIS grouping -- and deployments differ, so the metric emits the number and
the data table bands it. That keeps one metric usable under every banding rather than one
column per classification.

A measure, not a dimension: continuous, so it is absent from the registry's disaggregations
and no data table exposes it as a filter. The bands the standard data tables apply are in
tupaia-data-product.
{% enddocs %}
