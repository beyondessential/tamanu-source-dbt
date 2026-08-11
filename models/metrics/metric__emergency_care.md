{% docs metric__emergency_care %}
D5 wide-format metric view for the emergency care indicators registered in
csv/metric_definitions.csv: ed_attendance, ed_attendance_admitted and
ed_admission_rate. One row per (metric, reporting month, facility, sex, age band).

An ED attendance is an encounter whose first history segment carries OMOP visit concept
9203/Emergency Room Visit -- covering emergency, triage and observation -- counted at that
intake segment, so each arrival counts once. Attendances that went on to an inpatient
admission are included, and identified separately by ed_attendance_admitted.

Supersedes ds__emergency_visit, which carried the same attendance definition as a
standalone dataset. See specs/dbt-model/metric__emergency_care.md for BL-001..BL-007.
{% enddocs %}

{% docs metric__emergency_care__metric_id %}
The registered indicator identifier: 'ed_attendance', 'ed_attendance_admitted' or
'ed_admission_rate'. Joins to the canonical registry in csv/metric_definitions.csv, which
carries each one's definition, source and rationale.
{% enddocs %}

{% docs metric__emergency_care__variant_id %}
NULL -- these are the standard definitions, with no deployment-specific variant. A
deployment that needs a different definition registers a variant_of row in its own
metric_definitions extension and sets this column accordingly.
{% enddocs %}

{% docs metric__emergency_care__subject_id %}
NULL -- these are pre-aggregated counts, not per-subject rows.
{% enddocs %}

{% docs metric__emergency_care__period_start %}
First day of the reporting month, inclusive.
{% enddocs %}

{% docs metric__emergency_care__period_end %}
Last day of the reporting month, inclusive.
{% enddocs %}

{% docs metric__emergency_care__period_granularity %}
Constant 'month'. Every indicator here reports monthly.
{% enddocs %}

{% docs metric__emergency_care__value_numeric %}
The indicator value: a count for ed_attendance and ed_attendance_admitted, a percentage
(0-100, one decimal place) for ed_admission_rate.

Counts are additive across the disaggregation columns -- summing them over sex and age
band gives the facility total. **ed_admission_rate is not**: it is a proportion, so
summing it across disaggregations is meaningless. Re-derive the rate from the two counts
when aggregating.
{% enddocs %}

{% docs metric__emergency_care__value_boolean %}
NULL -- not used by these indicators.
{% enddocs %}

{% docs metric__emergency_care__age_group__who_primary_classification %}
Age band at the attendance date. The column is named for the classification that
produced it (macro `age_group__who_primary_classification`) rather than a generic
`age_group`, so a consumer can tell which banding it is reading without going back to the
model -- bands are not comparable across classifications.

Per the WHO primary age classification's range boundaries: '0-14 years', '15-24 years', '25-44 years', '45-59 years', '60-74 years',
'75+ years', or 'Unknown age' when the birth date is missing or the computed age is
implausible (negative, or over 120).
{% enddocs %}

{% docs metric__emergency_care__tupaia_facility_id %}
Tupaia's facility id, mapped from `facility_id` via the deployment's own
`tupaia_facility_mapping` seed. `'Not available'` -- never NULL, since this is a data table
filter column -- when the deployment has not configured a facility mapping, or when the
facility has no mapping entry.
{% enddocs %}
