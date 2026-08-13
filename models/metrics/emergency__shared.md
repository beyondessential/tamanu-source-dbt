{% docs emergency__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A
deployment that needs a different definition registers a variant_of row in its own
metric_definitions extension and sets this column accordingly.
{% enddocs %}

{% docs emergency__subject_id %}
The OMOP visit occurrence id of the ED visit
(clinical__visit_occurrence.visit_occurrence_id), matching the registry's subject_grain of
'visit'. Tamanu calls the same row an encounter.

One row per attendance, so this is unique within the metric -- an encounter has exactly one
intake segment, and only that segment is counted. A consumer needing a distinct count of
arrivals rather than a sum can therefore use count(distinct subject_id) and get the same
answer.

It is a visit id, not a patient id: the row carries no patient identifier, and a patient
with several visits appears once per visit with no way to link them from here. That is what
keeps these models unrestricted.
{% enddocs %}

{% docs emergency__period_start %}
Timestamp the patient arrived in the ED -- the start of the ED intake segment, to the minute.

Minute grain lets a consumer roll up to hour, day, week, month, quarter or year, and pair
with period_end to measure duration -- which period, and so which duration, is the
individual metric's. No period is withheld -- today's attendances are
emitted, and a consumer wanting only complete months excludes the current one in its own
date filter.
{% enddocs %}

{% docs emergency__period_granularity %}
Constant 'minute' -- period_start and period_end are timestamps resolved to the minute.
{% enddocs %}

{% docs emergency__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs emergency__triage_score %}
The acuity category assigned by the triage practitioner: '1' (most urgent) to '5', or
'Not recorded'.

A disaggregation, so a consumer groups by it to profile case mix, or filters to a category
to count presentations at that acuity. Additive like every other disaggregation here --
summing value_numeric across categories gives the facility total.

'Not recorded' covers two cases together: an attendance with no triage record at all, and a
triage record whose score is blank. `triages.score` is a nullable text column, so a blank
score is possible below the UI. The two are not distinguished, because from a case-mix
standpoint both mean "no acuity known" -- a consumer needing to tell them apart reads
`triages` directly.

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows.
{% enddocs %}


{% docs emergency__age_years %}
Age in whole years at arrival in the ED, from the patient's birth date.

Not banded. An age classification is a presentation choice -- WHO primary bands, five-year
bands, a national HMIS grouping -- and deployments differ, so the metric emits the number and
the data table bands it. That keeps one metric usable under every banding rather than one
column per classification.

A measure, not a dimension: continuous, so it is absent from the registry's disaggregations
and no data table exposes it as a filter. The bands the standard data tables apply are in
tupaia-data-product. NULL where the birth date is missing.
{% enddocs %}
