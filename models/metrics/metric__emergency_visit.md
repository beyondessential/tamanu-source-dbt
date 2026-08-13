{% docs metric__emergency_visit %}
D5 metric view for the emergency care attendance indicator registered in
documentations/metrics/*.yml: ed_visit. One row per ED attendance -- per-attendance
(subject) grain, so a consumer aggregates at whatever grain it needs.

An ED attendance is an encounter whose first history segment carries OMOP visit concept
9203/Emergency Room Visit -- covering emergency, triage and observation -- counted at that
intake segment, so each arrival counts once. Attendances that went on to an inpatient
admission are included, and flagged by is_admitted.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, sex, triage acuity, principal diagnosis chapter,
hour of arrival, admission outcome -- and over any time grain from
minute upwards. Nothing is pre-aggregated, so no dimension has to be collapsed to get a
total and the admission rate can be formed at any grain.

Total length of stay is period_end - period_start, where period_end is non-NULL -- arrival in
the ED to discharge from hospital. waiting_time__minutes carries the wait to active care.
metric__emergency_stay measures the emergency department portion of the stay.

Shares its attendance base with metric__emergency_stay via int__emergency_visits. That model
covers the same rows over the ED portion of the stay, and disaggregates by discharge
disposition and its own time-in-ED band rather than by diagnosis chapter, hour of arrival and
admission outcome.

See specs/dbt-model/metric__emergency_visit.md for BL-001..BL-016.
{% enddocs %}

{% docs metric__emergency_visit__period_end %}
Timestamp the encounter ended -- discharge from hospital, to the minute.

**The end of the encounter, not departure from the ED.** For an attendance that went on to an
inpatient admission this is the eventual hospital discharge, so period_end - period_start is
total length of stay, spanning the inpatient episode. metric__emergency_stay measures the ED
portion over the same rows.

**NULL while the encounter is open**, so this column is deliberately nullable: total length of
stay is undefined until the patient is discharged. A consumer measuring duration filters these
rows out; a consumer counting attendances keeps them.
{% enddocs %}

{% docs metric__emergency_visit__metric_id %}
The registered indicator identifier: always 'ed_visit'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.

The admission outcome is the is_admitted disaggregation rather than a separate id, so the
admitted count is the sum of value_numeric where is_admitted is true.
{% enddocs %}

{% docs metric__emergency_visit__value_numeric %}
Always 1 -- one attendance per row.

Sum it to count attendances over any grouping: over is_admitted for the admitted count,
over everything for the facility total, over nothing extra for a national total. Because it
is additive and nothing is pre-aggregated, no disaggregation has to be collapsed to get a
total, and the admission rate is formed as the admitted sum over the total sum at whatever
grain the consumer groups to. No pre-computed rate is emitted, because a proportion cannot
be rolled up.
{% enddocs %}

{% docs metric__emergency_visit__principal_diagnosis__icd10_chapter %}
WHO ICD-10 chapter of the encounter's principal diagnosis, labelled with the chapter's Roman
numeral and title -- e.g. 'X Diseases of the respiratory system'.

The name is principal_diagnosis__<grouping>: the concept before the `__`, the grouping after
it (macro `diagnosis__icd10_chapter`). A deployment preferring a different grouping adds
principal_diagnosis__icd10_block or principal_diagnosis__dhims2_group alongside, so a consumer
can always tell which one it is reading. Groupings are not comparable with each other.

A disaggregation, so a consumer groups by it for ED case mix, or filters to a chapter to
count presentations of that kind. Additive like every other disaggregation here.

Two fallbacks, kept distinct:

  'Not recorded' -- the encounter has no principal diagnosis (no `is_primary` row).
  'Unclassified' -- a code is recorded but resolves to no chapter: malformed, or in one of
  ICD-10's unassigned gaps.

Where an encounter carries more than one principal diagnosis, the earliest is used. Neither
label is ever NULL, since the data tables expose this as an array filter and Tupaia's array
filter drops NULL rows.

Note the labels do not sort into chapter order lexically ('X' sorts before 'XVIII' but after
'IV'). A consumer needing chapter order supplies it.
{% enddocs %}

{% docs metric__emergency_visit__waiting_time__minutes %}
Minutes the patient waited from triage to the start of active care, which is when the triage
record is closed.

Carried to two decimal places -- 0.6-second resolution, finer than any reporting need. A fixed
scale is needed because minutes from whole seconds is a repeating decimal. Mean wait is
avg(waiting_time__minutes) at whatever grain the consumer groups to; the median and the 90th
percentile come from the same column.

A measure, not a dimension: the value is continuous, so no data table exposes it as a filter and it is
not registered as a disaggregation. Group by triage_score to slice it by acuity.

Compliance against a target is the consumer's: compare this column to the deployment's target
for the row's triage_score, which var('triage_target_minutes') holds -- by default 2, 10, 30,
60 and 120 minutes for categories 1 to 5.

NULL until the patient reaches active care, so a wait-time visual restricts to non-NULL rows.
{% enddocs %}

{% docs metric__emergency_visit__ed_start__hour %}
Hour of the day the patient arrived in the ED, 0 to 23, for time-of-day profiling.

Tamanu stores naive timestamps in the deployment's central timezone (var('timezone')), so
this is already a local hour and no conversion is applied. A deployment whose facilities
span timezones gets the central zone's hour, not each facility's -- a caveat for
multi-timezone deployments rather than for the single-hospital case this was built for.

An integer rather than a label so it sorts and buckets naturally: a consumer wanting shifts
or a day/night split groups ranges of it.
{% enddocs %}

{% docs metric__emergency_visit__is_admitted %}
True when the attendance's encounter went on to an inpatient admission -- its visit-level
OMOP concept is 262 ('Emergency Room and Inpatient Visit'), meaning "arrived via the ED,
ended up an inpatient".

A disaggregation, not a separate metric: group by it to split attendances by outcome,
filter to it for the admitted count, or ignore it for the total.

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows, so the model coalesces a missing visit concept to false.
{% enddocs %}

{% docs metric__emergency_visit__length_of_stay__minutes %}
Minutes from arrival in the ED to discharge from hospital, so for an admitted patient it
spans the inpatient episode. metric__emergency_stay measures the emergency department
portion instead.

Carried to two decimal places, on the same basis as waiting_time__minutes. Not banded: a
four-hour split is a presentation choice a deployment may set differently, so the metric
emits the duration and the consumer's data table bands it.

A measure, not a dimension: continuous, so no data table exposes it as a filter and it is absent
from the registry's disaggregations. NULL while the encounter is open.
{% enddocs %}
