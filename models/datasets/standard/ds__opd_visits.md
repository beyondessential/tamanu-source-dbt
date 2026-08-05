{% docs ds__opd_visits %}
OPD visits dataset. One row per day per clinic (ward) with a count of outpatient
visits (encounters whose first history segment is clinic or vaccination), disaggregated by
facility, sex and OPD visit age band. Additive count only, so it can be aggregated
to any period.
{% enddocs %}

{% docs ds__opd_visits__age_group %}
OPD visit age band at the visit date: '<1 year', '1-4 years', '5-14 years',
'15-49 years', '50+ years', or 'Unknown age' when the birth date is missing, or the
computed age at the visit is negative or greater than 120 (implausible/bad data).
{% enddocs %}

{% docs ds__opd_visits__total_opd_visits %}
Count of OPD visits (clinic or vaccination encounters) in the group.
{% enddocs %}

{% docs ds__opd_visits__tupaia_facility_id %}
Tupaia's facility id, mapped from tamanu_facility_id via the deployment's own
tupaia_facility_mapping seed. 'Not available' (never NULL, since this is the data table's
filter column) when the deployment has not configured a facility mapping, or when the
facility has no mapping entry.
{% enddocs %}
