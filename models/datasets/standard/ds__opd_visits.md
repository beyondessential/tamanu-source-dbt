{% docs ds__opd_visits %}
OPD visits dataset. One row per day per clinic (ward) with a count of outpatient
visits (encounters whose first history segment is clinic or vaccination), disaggregated by
facility, sex and OPD visit age band. Additive count only, so it can be aggregated
to any period.
{% enddocs %}

{% docs ds__opd_visits__age_group %}
OPD visit age band at the visit date: '<1 year', '1-4 years', '5-14 years',
'15-49 years', '50+ years', or 'Unknown age' when the birth date is missing.
{% enddocs %}

{% docs ds__opd_visits__total_opd_visits %}
Count of OPD visits (clinic or vaccination encounters) in the group.
{% enddocs %}
