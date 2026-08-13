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
with period_end to measure time in the ED. No period is withheld -- today's attendances are
emitted, and a consumer wanting only complete months excludes the current one in its own
date filter.
{% enddocs %}

{% docs emergency__period_end %}
Timestamp the patient left the ED -- the end of the ED intake segment, to the minute.

**Departure from the ED, not the end of the encounter.** For an attendance that ended in
admission this is the moment of admission, so period_end - period_start is time in the ED,
not total hospital stay. The total-stay figure is the emergency triage line list's, computed
from the whole encounter.

**A planned location supplies the departure where the segment has no end.** An encounter
booked to transfer out of the ED carries planned_location_start_datetime, and the ED episode is
settled at that time even though the next segment is unrecorded. A recorded segment end always
takes precedence over the plan. Where the planned time is still in the future, the resulting
duration is a planned one -- the model reads no clock, so it does not distinguish a plan already
elapsed from one pending.

**NULL while the patient is in the ED with no transfer planned**, so this column is
deliberately nullable: time in the ED is undefined until they leave. A consumer measuring
duration filters these rows out; a consumer counting attendances ignores the column.
{% enddocs %}

{% docs emergency__period_granularity %}
Constant 'minute' -- period_start and period_end are timestamps resolved to the minute.
{% enddocs %}

{% docs emergency__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs emergency__age_group__who_primary_classification %}
Age band at the attendance date. The column is named for the classification that
produced it (macro `age_group__who_primary_classification`) rather than a generic
`age_group`, so a consumer can tell which banding it is reading without going back to the
model -- bands are not comparable across classifications.

Per the WHO primary age classification's range boundaries: '0-14 years', '15-24 years', '25-44 years', '45-59 years', '60-74 years',
'75+ years', or 'Unknown age' when the birth date is missing or the computed age is
implausible (negative, or over 120).
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

Never NULL -- this is a data table filter column, and Tupaia's default array filter drops
NULL rows.
{% enddocs %}

{% docs emergency__length_of_stay__4_hours_band %}
Total length of stay split at four hours: '< 4 hours', '4 or more hours', or 'Unknown'.

The duration is arrival in the ED to discharge from hospital, so for an admitted patient it
spans the inpatient episode. On metric__emergency_visit that is
period_end - period_start.

Four hours is the conventional emergency department threshold, and the column names it so a
different split added later reads as a different column. metric__emergency_stay bands the
emergency department portion under its own name, ed_time__4_hours_band.

'Unknown' marks an open encounter, where the duration is still running, and belongs in a
count of current activity.

Always populated -- this is a data table filter column, and Tupaia's default array filter
keeps the rows whose value is present. A consumer needing the exact duration rather than the
band computes it from period_start and period_end.
{% enddocs %}

{% docs emergency__ed_time__4_hours_band %}
Time in the emergency department split at four hours: '< 4 hours', '4 or more hours', or
'Unknown'.

The duration is arrival in the ED to departure from it -- whether that departure is an
internal transfer to an inpatient bed or a discharge straight from the ED. On
metric__emergency_stay that is period_end - period_start.

Four hours is the conventional emergency department threshold, and the column names it so a
different split added later reads as a different column. metric__emergency_visit bands
total length of stay, to hospital discharge, under its own name,
length_of_stay__4_hours_band.

'Unknown' marks a patient still in the ED, and belongs in a count of current activity.

Always populated -- this is a data table filter column, and Tupaia's default array filter
keeps the rows whose value is present.
{% enddocs %}
