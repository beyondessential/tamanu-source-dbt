{% docs metric__emergency_stay %}
D5 metric view for the emergency care stay indicator registered in
documentations/metrics/*.yml: ed_stay. One row per ED stay -- per-stay (subject) grain, so a
consumer aggregates at whatever grain it needs.

A stay is one ED attendance viewed as a span rather than an arrival: period_start is arrival
in the ED and period_end is departure from it, so period_end - period_start is time in the
ED. Departure is departure from the **ED**, not the end of the encounter -- for a stay that
ended in admission, period_end is the moment of admission.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, sex, age band, triage acuity, length-of-stay band, discharge disposition -- and
over any time grain from minute upwards.

Shares its attendance base with metric__emergency_visit via int__emergency_visits. Both
cover the same rows; a count of ed_stay equals a count of ed_visit over the same filter.
They differ in what they disaggregate by, so use this one for duration and disposition
questions and metric__emergency_visit for arrival, wait-time, diagnosis and admission
questions.

See specs/dbt-model/metric__emergency_stay.md for BL-001..BL-017.
{% enddocs %}

{% docs metric__emergency_stay__metric_id %}
The registered indicator identifier: always 'ed_stay'. Joins to the canonical registry in
documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__emergency_stay__value_numeric %}
Always 1 -- one ED stay per row.

Sum it to count stays over any grouping. A mean or median time in the ED is not this column:
it is period_end - period_start aggregated at the consumer's grain, since an interval is not
additive and cannot be pre-computed here.
{% enddocs %}

{% docs metric__emergency_stay__ed_time__minutes %}
Minutes the patient spent in the emergency department -- period_end - period_start, expressed
in minutes.

Carried to two decimal places, on the same basis as metric__emergency_visit's
waiting_time__minutes: 0.6-second resolution, with a fixed scale because minutes from whole
seconds is a repeating decimal. Mean time in the ED is avg(ed_time__minutes) at whatever grain
the consumer groups to; the median and the 90th percentile come from the same column.

A measure, not a dimension: the value is continuous, so it carries no data table filter and is
not registered as a disaggregation. ed_time__4_hours_band is the banded form for
grouping and filtering; this column is the underlying duration.

NULL only while the patient is in the ED with nothing booked and the encounter open -- the same rows
ed_time__4_hours_band reports as 'Unknown' -- so a duration visual restricts to non-NULL
rows.
{% enddocs %}

{% docs metric__emergency_stay__discharge_disposition %}
How the patient's encounter ended, from the Tamanu discharge record's disposition reference
data -- e.g. 'Home', 'Transfer to another facility', 'Died'. 'Not recorded' where the
encounter has no discharge record.

**Encounter-grained, not ED-grained.** The disposition describes how the whole encounter
ended, while this model's period covers only the ED portion. For a stay that was **not**
admitted the two coincide, because leaving the ED is the discharge. For a stay that **was**
admitted the disposition is the eventual hospital discharge, recorded well after period_end
-- so pairing a short time in the ED with a disposition of 'Died' does not mean the patient
died in the ED. Read alongside metric__emergency_visit's is_admitted when that
distinction matters.

'Not recorded' therefore covers a genuinely open encounter as well as a missing discharge
record, and is expected to be common for recent admitted stays.

Never NULL -- this is a data table filter column, and Tupaia's default array filter drops
NULL rows. Values are whatever the deployment's disposition reference data contains, so they
are not a fixed vocabulary and no accepted_values test constrains them.
{% enddocs %}
