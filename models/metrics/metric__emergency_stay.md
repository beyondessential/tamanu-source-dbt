{% docs metric__emergency_stay %}
D5 metric view for the emergency care stay indicator registered in
documentations/metrics/*.yml: ed_stay. One row per ED stay -- per-stay (subject) grain, so a
consumer aggregates at whatever grain it needs.

A stay is one ED attendance viewed as a span rather than an arrival: period_start is arrival
in the ED and period_end is departure from it, so period_end - period_start is time in the
ED. Departure is departure from the **ED**, not the end of the encounter -- for a stay that
ended in admission, period_end is the moment of admission.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, sex, age, triage acuity, discharge disposition -- and
over any time grain from minute upwards.

Shares its attendance base with metric__emergency_visit via int__emergency_visits. Both
cover the same rows; a count of ed_stay equals a count of ed_visit over the same filter.
They differ in what they disaggregate by, so use this one for duration and disposition
questions and metric__emergency_visit for arrival, wait-time, diagnosis and admission
questions.

See specs/dbt-model/metric__emergency_stay.md for BL-001..BL-017.
{% enddocs %}

{% docs metric__emergency_stay__period_end %}
Timestamp the patient left the emergency department, to the minute.

**Departure from the ED, not the end of the encounter.** For a stay that ended in admission
this is the moment the patient left the department, so period_end - period_start is time in the
ED, not total hospital stay. metric__emergency_visit measures the whole encounter over the same
rows.

**The departure is the earliest signal that the patient left**: the first move to another
location, or the time a booked transfer takes effect, falling through to the encounter end when
neither is recorded. A segment boundary alone is not a departure -- an encounter_type change to
admission closes the intake segment while the patient is still in the ED, so boarding time counts
toward the stay. Where the booked time is still in the future, the resulting duration is a planned
one: the model reads no clock, so it does not distinguish a plan already elapsed from one pending.

**NULL only while the patient is in the ED with nothing booked and the encounter open**, so this
column is deliberately nullable: time in the ED is undefined until they leave. A consumer
measuring duration filters these rows out; a consumer counting stays keeps them.
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

A measure, not a dimension: the value is continuous, so no data table exposes it as a filter and it is
not registered as a disaggregation. Not banded either -- a four-hour split is a presentation
choice a deployment may set differently, so the consumer's data table bands it.

NULL only while the patient is in the ED with nothing booked and the encounter open, so a
duration visual restricts to non-NULL rows.
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

Never NULL -- the data tables expose this as an array filter, and Tupaia's array filter drops
NULL rows. Values are whatever the deployment's disposition reference data contains, so they
are not a fixed vocabulary and no accepted_values test constrains them.
{% enddocs %}
