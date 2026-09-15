{% docs metric__birth %}
D5 metric view for the four maternity/newborn indicators registered in
documentations/metrics/maternity.yml: birth, low_birth_weight, preterm_birth, low_apgar_5min.
One row per registered live birth, per metric_id -- per-birth (subject) grain, so a consumer
aggregates at whatever grain it needs.

birth counts every registered live birth. low_birth_weight, preterm_birth and low_apgar_5min
are each a subset of birth's rows, sharing its base. Each subset is numerator-only: Tamanu
holds no population denominator, so no rate is stored (per D5 "Rate scale"), and each subset's
count is a fraction of *recorded* measurements, not of every birth.

Each subset is its own metric_id rather than a boolean disaggregation (the way ed_visit carries
is_admitted) because each depends on a measure that is often unrecorded -- a boolean would have
to collapse "not low birth weight" and "weight not recorded" into a single false.

Deployment-neutral: sourced from patient_birth_data, present across every Tamanu deployment,
with no visit or encounter concept -- a birth registration is patient-level, not visit-scoped.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, sex, delivery type, attendant, place, birth type -- and over any time grain from
day upwards. A rate (e.g. the low-birth-weight rate) is formed as
sum(value_numeric) filter (where metric_id = '<subset>') / sum(value_numeric) filter
(where metric_id = 'birth') at whatever grain the consumer groups to.

See specs/dbt-model/metric__birth.md for BL-001..BL-014.
{% enddocs %}

{% docs metric__birth__metric_id %}
The registered indicator identifier: one of 'birth', 'low_birth_weight', 'preterm_birth',
'low_apgar_5min'. Joins to the canonical registry in documentations/metrics/*.yml, which
carries each id's definition, source and rationale.
{% enddocs %}

{% docs metric__birth__variant_id %}
NULL -- this is the standard definition. No deployment variant of this metric exists.
{% enddocs %}

{% docs metric__birth__subject_id %}
The newborn's Tamanu patient_id. One birth per subject_id, since a twin birth is two separate
patient_birth_data rows (one per baby).
{% enddocs %}

{% docs metric__birth__period_start %}
The birth's date at day resolution -- the patient's date of birth, falling back to the birth
record's registration date where no date of birth is held.

Tamanu does not reliably capture time of birth, so this model does not attempt minute
resolution and birth_time plays no part: at day granularity it cannot change the result.
int__patient_birth_measurements does use it, because the OMOP MEASUREMENT domain needs the
finer grain.
{% enddocs %}

{% docs metric__birth__period_end %}
Equal to period_start. A birth is a point event with no duration, unlike an encounter, so
there is no "open" state for a NULL to signal.
{% enddocs %}

{% docs metric__birth__period_granularity %}
Always 'day'.
{% enddocs %}

{% docs metric__birth__value_numeric %}
Always 1 -- one birth per row.

Sum it to count births over any grouping. Sum it filtered to a subset metric_id (e.g.
low_birth_weight) over the sum filtered to birth for the same grouping to form a rate --
formed at whatever grain the consumer groups to, never stored here.
{% enddocs %}

{% docs metric__birth__value_boolean %}
NULL -- this metric's value is the count in value_numeric.
{% enddocs %}

{% docs metric__birth__facility_id %}
The birth facility, carried as patient_birth_data.birth_facility_id exactly as recorded.
Nullable: a home or other-place birth genuinely has none -- unlike ed_visit's inner-joined
facility, no row is excluded or coalesced here to force a value.

The id is deliberately not resolved against bases/facilities. That base filters
deleted_at is null, so a birth at a facility since retired would come back NULL and join the
home/other-place bucket -- turning a data gap into what reads as a real home birth, the one
thing a NULL here is documented never to be.

**A data table must label the NULL, not filter it.** Tupaia's array filter drops NULL rows, so
exposing this column as an array filter silently removes every home and other-place birth --
which is exactly the population a "deliveries by place" split exists to show. Set an
unmatched/unknown label (as the Tupaia facility crosswalk does) rather than letting the NULL
fall through. metric__emergency_visit's is_admitted coalesces in the model for this reason;
here the NULL is meaningful, so it survives to the consumer and the consumer handles it.
{% enddocs %}

{% docs metric__birth__birth_delivery_type %}
Raw source value: normal_vaginal_delivery, breech, emergency_c_section, elective_c_section,
vacuum_extraction, forceps or other. Ungrouped -- relabelling to a human-readable form (as
ds__births does for a line list) is the consumer's data table's job.

Never NULL: an unrecorded delivery type reads 'Not recorded'. Tupaia's array filter drops NULL
rows, so a raw NULL would silently remove the birth from a "by delivery type" split and stop it
reconciling with the birth total. Unlike facility_id, a NULL here carries no meaning of its own
-- it is an unfilled field, not a home birth -- so the model fills it rather than passing the
problem to the consumer.
{% enddocs %}

{% docs metric__birth__attendant_at_birth %}
Raw source value: doctor, midwife, nurse, traditional_birth_attentdant [sic, matches the
source data] or other. Ungrouped and never NULL, same treatment as birth_delivery_type --
an unrecorded attendant reads 'Not recorded'.
{% enddocs %}

{% docs metric__birth__registered_birth_place %}
Raw source value: health_facility, home or other. Ungrouped and never NULL, same treatment
as birth_delivery_type -- an unrecorded place reads 'Not recorded'.
{% enddocs %}
