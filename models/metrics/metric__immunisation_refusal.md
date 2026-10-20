{% docs metric__immunisation_refusal %}
D5 metric view for the immunisation refusal indicator registered in
documentations/metrics/*.yml: immunisation_refusal. One row per vaccination attempt recorded
as not given -- per-attempt (subject) grain, so a consumer aggregates at whatever grain it
needs.

An attempt is a `clinical__observation` row of type `'vaccination not given'` --
`bases/vaccine_administrations` with `status = 'NOT_GIVEN'` -- attributed to the facility it
was recorded at.

Sibling of `metric__immunisation_dose`: same disaggregation shape (antigen, dose position,
facility, sex, EPI age cohort, patient village, vaccine, location group), plus why the dose
was not given. A different `metric_id`, not a `status` disaggregation on the dose metric --
see that model's spec, Open questions, for why.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations, and
over any time grain from day upwards. Nothing is pre-aggregated, so no dimension has to be
collapsed to get a total.

See specs/dbt-model/metric__immunisation_refusal.md for BL-001..BL-011.
{% enddocs %}

{% docs metric__immunisation_refusal__metric_id %}
The registered indicator identifier: always 'immunisation_refusal'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__immunisation_refusal__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs metric__immunisation_refusal__subject_id %}
The attempt's observation id (clinical__observation.observation_id, the underlying
administered_vaccines id for a not-given row), matching the registry's subject_grain of
'attempt'.

One row per attempt, so this is unique within the metric -- a patient with two vaccines
refused in the same encounter yields two rows, not one, since each is its own
administered_vaccines record.

It is an attempt id, not a patient id: a patient with several refused attempts appears once
per attempt. The patient is carried separately in person_id, which is why this model is
restricted (BL-011).
{% enddocs %}

{% docs metric__immunisation_refusal__period_start %}
Calendar day the attempt was recorded as not given.

Day grain lets a consumer roll up to week, month, quarter or year. No period is withheld --
today's attempts are emitted, and a consumer wanting only complete periods excludes the
current one in its own date filter.
{% enddocs %}

{% docs metric__immunisation_refusal__period_end %}
Always equal to period_start. A not-given attempt is a single-day point event -- there is no
span to measure.
{% enddocs %}

{% docs metric__immunisation_refusal__period_granularity %}
Constant 'day' -- period_start and period_end are dates, not timestamps.
{% enddocs %}

{% docs metric__immunisation_refusal__value_numeric %}
Always 1 -- one attempt per row.

Sum it to count refused attempts over any grouping: over everything for the facility total,
over nothing extra for the national total. Because it is additive and nothing is
pre-aggregated, no disaggregation has to be collapsed to get a total.
{% enddocs %}

{% docs metric__immunisation_refusal__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__immunisation_refusal__disease %}
The antigen the attempt addresses (e.g. Measles, Polio) --
bases/vaccine_administrations.disease, read directly since disease has no OMOP OBSERVATION
equivalent. 'Not recorded' when the field was left blank.
{% enddocs %}

{% docs metric__immunisation_refusal__age_group__who_epi_schedule %}
EPI-style age cohort at the attempt date, banded in months: '<1 year', '12-23 months',
'24-59 months', or '5+ years'. 'Unknown age' when the patient's birth date is missing. Same
macro and rationale as metric__immunisation_dose -- see macros/age_group__who_epi_schedule.sql.
{% enddocs %}

{% docs metric__immunisation_refusal__dose_label %}
The schedule's dose position for this attempt (e.g. 'Dose 1', 'Dose 2', or a due-time label
like 'Birth'/'6 weeks') -- vaccine_schedules.dose_label via the attempt's
scheduled_vaccine_id. 'Not recorded' for an ad hoc/catch-up attempt that carries no schedule
at all.
{% enddocs %}

{% docs metric__immunisation_refusal__patient_location_id %}
The patient's own home village (clinical__person.location_id, an id into ref__location) --
where the patient lives, not where the attempt was recorded. Distinct from facility_id, which
is the recording facility.

NULL when the patient's own record carries no village. Not coalesced to a placeholder -- this
is an id column a consumer joins to ref__location, not a label, so a real NULL is more useful
than a sentinel string.
{% enddocs %}

{% docs metric__immunisation_refusal__reason %}
Why the dose was not given -- bases/vaccine_administrations' coded not_given_reason_id
(resolved to its reference_data name) when captured, else the free-text reason. 'Not
recorded' when neither was captured.
{% enddocs %}

{% docs metric__immunisation_refusal__person_id %}
The patient's Tamanu id -- the patient of the encounter the attempt was recorded in. Lets a
consumer count people rather than attempts: a distinct count over this column. Never NULL.

Restricted: carried for aggregation only. A Tupaia data table uses it inside `count_distinct`
and never exposes it as a column, so no patient id reaches a dashboard.
{% enddocs %}

{% docs metric__immunisation_refusal__vaccine_id %}
The scheduled vaccine's drug id (vaccine_schedules.vaccine_id, e.g. `drug-TCVTyphoid`) --
the stable key a consumer filters one vaccine by. NULL for an ad hoc attempt with no schedule.
{% enddocs %}

{% docs metric__immunisation_refusal__vaccine_label %}
The scheduled vaccine's display label (vaccine_schedules.label, e.g. `BCG`, `Hepatitis B`).
'Not recorded' for an ad hoc attempt with no schedule.
{% enddocs %}

{% docs metric__immunisation_refusal__vaccine_category %}
The schedule's category (vaccine_schedules.category, e.g. `Routine`, `Catchup`, `Campaign`), as
the deployment configures it. 'Not recorded' for an ad hoc attempt with no schedule.
{% enddocs %}

{% docs metric__immunisation_refusal__location_group_id %}
The location group (area or site) of the location the attempt was recorded at, as a Tamanu id
-- one level finer than facility_id, so a consumer can attribute a campaign site. NULL when the
location belongs to no group.
{% enddocs %}

{% docs metric__immunisation_refusal__age_days %}
The patient's age on the attempt date in whole days. NULL with no date of birth on record. A
measure, unbanded -- a consumer bands it (e.g. days after birth for a birth dose).
{% enddocs %}

{% docs metric__immunisation_refusal__age_years %}
The patient's age on the attempt date in whole completed years. NULL with no date of birth on
record. A measure, unbanded -- a consumer bands it.
{% enddocs %}
