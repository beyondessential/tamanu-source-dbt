{% docs metric__outpatient_visit %}
D5 metric view for the outpatient department indicator registered in
documentations/metrics/*.yml: opd_visit. One row per outpatient visit -- per-visit
(subject) grain, so a consumer aggregates at whatever grain it needs.

An outpatient visit is an encounter whose first history segment carries OMOP visit concept
9202/Outpatient Visit -- covering clinic, vaccination and imaging -- counted at that intake
segment, so each visit counts once.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, location, sex, clinician, admission outcome, admitting clinician, and whether the
discharge was system-generated -- and over any time grain from day upwards. Nothing is
pre-aggregated, so no dimension has to be collapsed to get a total.

Two measures ride alongside the count and are not summed as if they were one: age_years,
and opd_time__minutes, the time in the outpatient department. Both are emitted per visit and
unbanded, so a consumer forms whatever mean, median or band set it needs.

See specs/dbt-model/metric__outpatient_visit.md for BL-001..BL-012.
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
Calendar day the encounter ended. NULL while the encounter is still open.

Tamanu tracks a date only for outpatient encounters, not a timestamp -- there is no
arrival/departure pair to the minute the way there is for an ED attendance, so
period_end - period_start gives whole days, not a precise duration.
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

{% docs metric__outpatient_visit__clinician_id %}
Tamanu `users.id` of the clinician recorded on the outpatient intake segment -- who saw the
patient in the outpatient department.

The Tamanu id, untranslated. Resolving it to a name is a consumer-layer concern, the same
division `facility_id` and `location_id` follow: a consumer joins `map__clinician` at its
data table. Keeping the name out of the metric is also what stops a staff directory becoming
part of the metric contract.

Nullable -- an intake segment recorded with no clinician keeps the visit and leaves this
NULL, rather than dropping it. A consumer exposing it as an array filter labels the NULL,
since Tupaia's array filter drops NULL rows.
{% enddocs %}

{% docs metric__outpatient_visit__is_admitted %}
Whether the encounter that began as this outpatient visit went on to an inpatient admission
-- true where it later carries a segment at OMOP visit concept 9201 (Inpatient Visit).

A disaggregation, not a separate metric: the admitted share is
`sum(value_numeric) filter (where is_admitted) / sum(value_numeric)`, formed at whatever
grain the consumer groups to. The model emits no rate, because a proportion is not additive
and summing one across facility, sex or age band is meaningless.

False, never NULL, where the visit was not admitted -- the data tables expose this as an
array filter, and Tupaia's array filter drops NULL rows.
{% enddocs %}

{% docs metric__outpatient_visit__admission_clinician_id %}
Tamanu `users.id` of the clinician recorded on the admission segment -- who admitted the
patient.

Deliberately not `clinician_id`: the clinician who saw the patient in clinic and the one
recorded at the point of admission are different people in general, so both are kept and a
consumer picks the attribution its question calls for. "Admissions by clinician" over this
column counts who admitted; the same card over `clinician_id` filtered to `is_admitted`
counts whose clinic patients ended up admitted.

NULL for a visit that was never admitted, and for an admission segment recorded with no
clinician. The Tamanu id, untranslated, for the same reason as `clinician_id`.
{% enddocs %}

{% docs metric__outpatient_visit__is_auto_discharge %}
Whether the encounter's discharge was system-generated rather than recorded by a clinician
-- true where the discharge note begins `Automatically discharged`.

This matters because such a discharge carries the sweep's clock, not the time the patient
actually left: Tamanu's outpatient discharger closes encounters left open at the end of the
day, so an auto-discharged visit's `opd_time__minutes` is an artefact of when the job ran.
A consumer forming a mean duration excludes these; a consumer counting visits keeps them,
which is why they are flagged rather than filtered out.

The same rule as `macros/datasets/discharge_audit.sql` BL-004, deliberately, so the repo
holds one definition of a system discharge. It does not catch a discharge a deployment's own
data migration fabricated under a different note -- see BL-012 in the spec.

False, never NULL, covering both a clinician-recorded discharge and an encounter with no
discharge record at all.
{% enddocs %}

{% docs metric__outpatient_visit__opd_time__seconds %}
Time in the outpatient department in whole seconds -- intake to the end of the outpatient
episode. The basis for `opd_time__minutes`; emitted alongside it so a consumer needing
another scale is not re-deriving one from a rounded number.

NULL while the encounter is open and nothing has ended the outpatient episode.
{% enddocs %}

{% docs metric__outpatient_visit__opd_time__minutes %}
Time in the outpatient department in minutes, to two decimal places -- from the intake
segment to the end of the outpatient episode.

The episode ends at the first segment carrying a concept other than 9202, falling back to
the encounter end for a visit that never left outpatient care. A later 9202 segment is a
clinician handover or a move between clinic rooms, not a departure, so it does not end it.
This is the minute-resolution duration; `period_end - period_start` is whole days, since
both are dates.

Not banded and not averaged. A mean, a median or a band set are all presentation choices a
deployment may set differently, so the metric emits the number per visit and the consumer
forms what it needs -- the same division `age_years` follows. A weighted mean is
`sum(opd_time__minutes) / count of the visits that have one`; forming it in the data table
instead would return a mean per group, and a report combining groups would be averaging
averages.

Read it with `is_auto_discharge`: an auto-discharged visit has a duration, but it is the
discharge sweep's clock rather than the patient's. NULL while the encounter is open, which
is not a duration of zero -- those visits leave a mean's denominator as well as its
numerator.
{% enddocs %}
