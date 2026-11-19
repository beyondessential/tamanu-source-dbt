{% docs metric__appointment %}
D5 metric view for the outpatient appointment indicator registered in
documentations/metrics/*.yml: outpatient_appointment. One row per scheduled outpatient
appointment, whatever its status -- per-appointment (subject) grain, so a consumer aggregates at
whatever grain it needs.

Aggregate by summing value_numeric (always 1) over any subset of the disaggregations --
facility, clinic (location group), appointment status, appointment type and sex -- and over any
time grain from minute upwards. No-shows are the rows whose appointment_status is 'No-show'; a
no-show rate is that count over the appointments a consumer counts as booked, formed at the
consumer's grain.

age_years rides alongside the count as a measure, unbanded.

See specs/dbt-model/metric__appointment.md for BL-001..BL-011.
{% enddocs %}

{% docs metric__appointment__metric_id %}
The registered indicator identifier: always 'outpatient_appointment'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__appointment__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant.
{% enddocs %}

{% docs metric__appointment__subject_id %}
The Tamanu appointment id. One row per appointment, so count(distinct subject_id) and
sum(value_numeric) agree.
{% enddocs %}

{% docs metric__appointment__period_start %}
The appointment's scheduled start, truncated to the minute (BL-004).
{% enddocs %}

{% docs metric__appointment__period_end %}
The appointment's scheduled end, truncated to the minute (BL-004). NULL where the appointment
records no end.
{% enddocs %}

{% docs metric__appointment__period_granularity %}
Always 'minute' -- period_start and period_end are minute-resolution timestamps.
{% enddocs %}

{% docs metric__appointment__value_numeric %}
Always 1 -- one appointment per row (BL-003). Additive, so a data table summing it is correct at
every grain.
{% enddocs %}

{% docs metric__appointment__value_boolean %}
NULL -- this metric's value is the count in value_numeric.
{% enddocs %}

{% docs metric__appointment__age_years %}
The patient's age in whole years on the appointment's start date (BL-009). A measure, not a
dimension -- banding is the consumer's. NULL where the patient has no date of birth.
{% enddocs %}

{% docs metric__appointment__appointment_status %}
The appointment's current Tamanu status, as recorded -- e.g. Confirmed, Arrived, Assessed, Seen,
No-show, Cancelled (BL-007). It is the status the appointment holds now, not on its date.

Never NULL ('Not recorded' as a fallback): the data tables expose this as an array filter and
Tupaia's array filter drops NULL rows.
{% enddocs %}

{% docs metric__appointment__appointment_type %}
The appointment type, resolved to its reference-data name (BL-008). 'Not recorded' where the
type no longer resolves. Never NULL, for the same reason as appointment_status.
{% enddocs %}

{% docs metric__appointment__location_group_name %}
The location group the appointment is booked in -- the clinic or area -- resolved to its name
(BL-006). The same column, and the same clinic list, as metric__outpatient_visit's
location_group_name. Never NULL, for the same reason as appointment_status.
{% enddocs %}
