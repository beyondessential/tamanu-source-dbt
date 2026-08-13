{% docs metric__outpatient_visit %}
D5 metric view for the outpatient department indicator registered in
documentations/metrics/*.yml: opd_visit. One row per outpatient visit -- per-visit
(subject) grain, so a consumer aggregates at whatever grain it needs.

An outpatient visit is an encounter whose first history segment carries OMOP visit concept
9202/Outpatient Visit -- covering clinic, vaccination and imaging -- counted at that intake
segment, so each visit counts once.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, area, sex -- and over any time grain from day upwards. Nothing is pre-aggregated,
so no dimension has to be collapsed to get a total.

See specs/dbt-model/metric__outpatient_visit.md for BL-001..BL-008.
{% enddocs %}

{% docs metric__outpatient_visit__metric_id %}
The registered indicator identifier: always 'opd_visit'. Joins to the canonical registry in
documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__outpatient_visit__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs metric__outpatient_visit__subject_id %}
The OMOP visit occurrence id of the outpatient visit
(clinical__visit_occurrence.visit_occurrence_id), matching the registry's subject_grain of
'visit'. Tamanu calls the same row an encounter.

One row per visit, so this is unique within the metric -- an encounter has exactly one
intake segment, and only that segment is counted. A consumer needing a distinct count of
visits rather than a sum can therefore use count(distinct subject_id) and get the same
answer.

It is a visit id, not a patient id: the row carries no patient identifier, and a patient
with several visits appears once per visit with no way to link them from here. That is what
keeps this model unrestricted.
{% enddocs %}

{% docs metric__outpatient_visit__period_start %}
Calendar day of the visit -- the date of the outpatient intake segment.

Day grain lets a consumer roll up to week, month, quarter or year. No period is withheld --
today's visits are emitted, and a consumer wanting only complete periods excludes the
current one in its own date filter.
{% enddocs %}

{% docs metric__outpatient_visit__period_end %}
Always NULL. Tamanu tracks the visit date only for outpatient encounters -- there is no
arrival/departure timestamp pair the way there is for an ED attendance, so no duration is
computable and none is emitted.
{% enddocs %}

{% docs metric__outpatient_visit__period_granularity %}
Constant 'day' -- period_start is a date, not a timestamp.
{% enddocs %}

{% docs metric__outpatient_visit__value_numeric %}
Always 1 -- one visit per row.

Sum it to count visits over any grouping: over everything for the facility total, over
nothing extra for the national total. Because it is additive and nothing is
pre-aggregated, no disaggregation has to be collapsed to get a total.
{% enddocs %}

{% docs metric__outpatient_visit__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__outpatient_visit__age_years %}
Age in whole years at the visit date, from the patient's birth date. NULL when the birth
date is missing.

Not banded. An age classification is a presentation choice -- WHO primary bands, five-year
bands, a national HMIS grouping -- and deployments differ, so the metric emits the number
and the data table bands it. That keeps one metric usable under every banding rather than
one column per classification.

A measure, not a dimension: continuous, so it is absent from the registry's disaggregations
and no data table exposes it as a filter. The bands the standard data tables apply are in
tupaia-data-product.
{% enddocs %}
