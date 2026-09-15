{% docs metric__inpatient_admission %}
D5 metric view for the inpatient admission indicator registered in
documentations/metrics/*.yml: inpatient_admission. One row per hospital admission --
per-admission (subject) grain, so a consumer aggregates at whatever grain it needs.

An admission is an encounter's earliest segment whose OMOP visit concept is 9201/Inpatient
Visit -- the segment where the patient became an inpatient, whether or not it followed an
ED/triage/observation phase. Admissions reached via the ED are flagged by
is_admitted_via_emergency.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, ward, sex, admission source, arrival via ED, principal diagnosis chapter, discharge
disposition -- and over any time grain from minute upwards. Grouping on period_start counts
admissions in a period; grouping on period_end counts discharges over the same rows, so there
is no separate discharge metric_id.

Length of stay is period_end - period_start, where period_end is non-NULL -- becoming an
inpatient to discharge from hospital.

See specs/dbt-model/metric__inpatient_admission.md for BL-001..BL-015.
{% enddocs %}

{% docs metric__inpatient_admission__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs metric__inpatient_admission__subject_id %}
The OMOP visit occurrence id of the admission (clinical__visit_occurrence.visit_occurrence_id),
matching the registry's subject_grain of 'visit'. Tamanu calls the same row an encounter.

One row per admission, so this is unique within the metric -- an encounter has exactly one
admission segment, and only that segment is counted. A consumer needing a distinct count of
admissions rather than a sum can therefore use count(distinct subject_id) and get the same
answer.

It is a visit id, not a patient id: the row carries no patient identifier, and a patient with
several admissions appears once per admission with no way to link them from here. That is what
keeps this model unrestricted.
{% enddocs %}

{% docs metric__inpatient_admission__metric_id %}
The registered indicator identifier: always 'inpatient_admission'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__inpatient_admission__period_start %}
Timestamp the patient became an inpatient -- the start of the admission segment, to the
minute.

For a direct admission this is the encounter's start; for an admission reached via the ED it is
later than the encounter's start, since the ED/triage/observation portion is out of scope for
this metric (metric__emergency_visit / metric__emergency_stay cover that portion).

Minute grain lets a consumer roll up to hour, day, week, month, quarter or year, and pair with
period_end to measure duration. No period is withheld -- today's admissions are emitted, and a
consumer wanting only complete months excludes the current one in its own date filter.
{% enddocs %}

{% docs metric__inpatient_admission__period_end %}
Timestamp the encounter ended -- discharge from hospital, to the minute.

**NULL while the encounter is open**, so this column is deliberately nullable: length of stay
is undefined until the patient is discharged. A consumer measuring duration filters these rows
out; a consumer counting admissions keeps them.
{% enddocs %}

{% docs metric__inpatient_admission__period_granularity %}
Constant 'minute' -- period_start and period_end are timestamps resolved to the minute.
{% enddocs %}

{% docs metric__inpatient_admission__value_numeric %}
Always 1 -- one admission per row.

Sum it to count admissions over any grouping: over is_admitted_via_emergency for the
ED-arrival count, over everything for the facility total, over nothing extra for a national
total. Because it is additive and nothing is pre-aggregated, no disaggregation has to be
collapsed to get a total.
{% enddocs %}

{% docs metric__inpatient_admission__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__inpatient_admission__age_years %}
Age in whole years at admission, from the patient's birth date.

Not banded. An age classification is a presentation choice -- WHO primary bands, five-year
bands, a national HMIS grouping -- and deployments differ, so the metric emits the number and
the data table bands it.

A measure, not a dimension: continuous, so it is absent from the registry's disaggregations and
no data table exposes it as a filter. NULL where the birth date is missing.
{% enddocs %}

{% docs metric__inpatient_admission__admission_ward_id %}
The Tamanu department id (ward) the patient was admitted to -- the admission segment's
department_id, carried as-is.

A disaggregation, so a consumer groups by it to profile ward activity, or filters to a ward to
count admissions to it. Emitted as the Tamanu id only, the same convention facility_id uses --
resolving it to a name is a consumer-layer concern. NULL where the admission segment carries no
department.
{% enddocs %}

{% docs metric__inpatient_admission__admission_source %}
How the patient arrived, from the encounter's referral source: the reference-data name, or
'Not recorded'.

A disaggregation, so a consumer groups by it to profile admission sources, or filters to one to
count admissions from it. Carried as recorded in Tamanu's deployment-configured reference data
rather than mapped to AIHW's fixed admission-mode vocabulary (see the spec's DV-001) --
is_admitted_via_emergency covers the one admission-mode category this model can derive
unambiguously.

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows.
{% enddocs %}

{% docs metric__inpatient_admission__is_admitted_via_emergency %}
True when the admission's encounter had a prior ED/triage/observation phase -- its visit-level
OMOP concept is 262 ('Emergency Room and Inpatient Visit').

metric__emergency_visit.is_admitted describes the same admissions from the opposite end of the
encounter, and the two are not expected to sum to the same total -- an admission with no
preceding ED phase never appears in metric__emergency_visit at all.

A disaggregation, not a separate metric: group by it to split admissions by arrival route,
filter to it for the ED-arrival count, or ignore it for the total.

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows, so the model coalesces a missing visit concept to false.
{% enddocs %}

{% docs metric__inpatient_admission__principal_diagnosis__icd10_chapter %}
WHO ICD-10 chapter of the encounter's principal diagnosis, labelled with the chapter's Roman
numeral and title -- e.g. 'X Diseases of the respiratory system'.

The name is principal_diagnosis__<grouping>: the concept before the `__`, the grouping after it
(macro `diagnosis__icd10_chapter`).

A disaggregation, so a consumer groups by it for case mix, or filters to a chapter to count
admissions of that kind. Additive like every other disaggregation here.

Two fallbacks, kept distinct: 'Not recorded' -- the encounter has no principal diagnosis (no
`is_primary` row); 'Unclassified' -- a code is recorded but resolves to no chapter (malformed,
or in one of ICD-10's unassigned gaps). Where an encounter carries more than one principal
diagnosis, the earliest is used. Neither label is ever NULL.
{% enddocs %}

{% docs metric__inpatient_admission__discharge_disposition %}
How the encounter ended: the disposition reference-data name, or 'Not recorded'.

A disaggregation, so a consumer groups by it to profile discharge outcomes, or filters to one
to count admissions ending that way. Mirrors AIHW's mode of separation concept as a BES
composition rather than an implementation of its coded vocabulary (see the spec's BL-014).

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows.
{% enddocs %}

{% docs metric__inpatient_admission__length_of_stay__minutes %}
Minutes from becoming an inpatient to discharge from hospital.

Carried to two decimal places. Not banded: a length-of-stay band is a presentation choice a
deployment may set differently, so the metric emits the duration and the consumer's data table
bands it.

A measure, not a dimension: continuous, so no data table exposes it as a filter and it is
absent from the registry's disaggregations. NULL while the encounter is open.
{% enddocs %}

{% docs metric__inpatient_admission__is_readmission_within_30_days %}
True where the immediately preceding admission for the same patient discharged no more than 30
days before this one started.

Computed by ordering each patient's admissions by start time internally -- the patient
identifier used to do that is never selected into this model's output, the same "derive from,
don't expose" pattern age_years already uses against the birth date. This row still carries no
patient identifier: the flag says an admission followed another one within 30 days, not which
admission, when, or for whom.

A disaggregation, so a consumer groups by it or filters to it -- e.g. the share of admissions
that are readmissions is sum(value_numeric) filter (where is_readmission_within_30_days) /
sum(value_numeric), the same ratio shape as is_admitted_via_emergency.

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows, so the model coalesces to false where there is no previous admission, the previous
one is still open, or the two overlap (a data-entry anomaly, not a readmission).
{% enddocs %}
