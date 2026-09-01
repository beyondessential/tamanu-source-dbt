{% docs metric__immunisation_dose %}
D5 metric view for the immunisation dose indicator registered in
documentations/metrics/*.yml: immunisation_dose. One row per vaccine dose given -- per-dose
(subject) grain, so a consumer aggregates at whatever grain it needs.

A dose is a `clinical__drug_exposure` row of type `vaccination` -- which already excludes
everything except `status = 'GIVEN'` administrations -- attributed to the facility it was
physically given at.

Numerator-only: this counts doses, not coverage. A coverage percentage is a ratio against an
externally supplied population/target estimate, computed downstream (Tupaia), never in dbt.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, sex, disease/antigen, EPI age cohort, schedule dose position, patient village --
and over any time grain from day upwards. Nothing is pre-aggregated, so no dimension has to
be collapsed to get a total.

See specs/dbt-model/metric__immunisation_dose.md for BL-001..BL-009.
{% enddocs %}

{% docs metric__immunisation_dose__metric_id %}
The registered indicator identifier: always 'immunisation_dose'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__immunisation_dose__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs metric__immunisation_dose__subject_id %}
The dose's drug exposure id (clinical__drug_exposure.drug_exposure_id, the underlying
administered_vaccines id for a vaccination row), matching the registry's subject_grain of
'dose'.

One row per dose, so this is unique within the metric -- a patient given two vaccines in the
same encounter yields two rows, not one, since each is its own administered_vaccines record.

It is a dose id, not a patient id: the row carries no patient identifier, and a patient with
several doses appears once per dose with no way to link them from here. That is what keeps
this model unrestricted.
{% enddocs %}

{% docs metric__immunisation_dose__period_start %}
Calendar day the dose was given.

Day grain lets a consumer roll up to week, month, quarter or year. No period is withheld --
today's doses are emitted, and a consumer wanting only complete periods excludes the current
one in its own date filter.
{% enddocs %}

{% docs metric__immunisation_dose__period_end %}
Always equal to period_start. A dose is a single-day point event -- there is no span to
measure, unlike an attendance or an admission.
{% enddocs %}

{% docs metric__immunisation_dose__period_granularity %}
Constant 'day' -- period_start and period_end are dates, not timestamps.
{% enddocs %}

{% docs metric__immunisation_dose__value_numeric %}
Always 1 -- one dose per row.

Sum it to count doses over any grouping: over everything for the facility total, over
nothing extra for the national total. Because it is additive and nothing is pre-aggregated,
no disaggregation has to be collapsed to get a total. This is the numerator of a coverage
ratio -- the denominator (a target population estimate) is supplied downstream, not here.
{% enddocs %}

{% docs metric__immunisation_dose__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__immunisation_dose__disease %}
The antigen the dose addresses (e.g. Measles, Polio) -- bases/vaccine_administrations.disease,
read directly since disease has no OMOP DRUG_EXPOSURE equivalent and so is not carried on
clinical__drug_exposure. 'Not recorded' when the field was left blank.
{% enddocs %}

{% docs metric__immunisation_dose__age_group__who_epi_schedule %}
EPI-style age cohort at the dose date, banded in months: '<1 year', '12-23 months',
'24-59 months', or '5+ years'. 'Unknown age' when the patient's birth date is missing.

Banded here, unlike the unbanded age_years measure other metric__ models emit -- the
coverage ratio this numerator feeds is itself age-cohort specific (e.g. "doses given to
children under 1 year"), so the band is part of the definition, not a downstream
presentation choice. See macros/age_group__who_epi_schedule.sql.
{% enddocs %}

{% docs metric__immunisation_dose__dose_label %}
The schedule's dose position for this dose (e.g. 'Dose 1', 'Dose 2', or a due-time label
like 'Birth'/'6 weeks') -- vaccine_schedules.dose_label via the dose's scheduled_vaccine_id.
'Not recorded' for an ad hoc/catch-up dose that carries no schedule at all.

Combined with disease, this is what standard coverage indicators actually key on (e.g.
"DTP3", "MCV1" -- antigen plus dose number), closer to a WUENIC-style indicator than
disease alone.
{% enddocs %}

{% docs metric__immunisation_dose__patient_location_id %}
The patient's own home village (clinical__person.location_id, an id into ref__location) --
where the patient lives, not where the dose was given. Distinct from facility_id, which is
the administering facility.

NULL when the patient's own record carries no village. Not coalesced to a placeholder --
this is an id column a consumer joins to ref__location, not a label, so a real NULL is more
useful than a sentinel string.

Exists because a future coverage percentage will be computed against a population estimate
that is itself geographic (by village/catchment), not per-facility -- a child vaccinated at
a different facility to where they live should still count toward their own village's
coverage, not the administering facility's throughput.
{% enddocs %}
