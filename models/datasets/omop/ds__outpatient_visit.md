{% docs ds__outpatient_visit %}
Outpatient visits dataset. One row per day per clinic (area) with a count of outpatient
visits (encounters whose first history segment has OMOP visit concept 9202/Outpatient
Visit -- clinic, vaccination, or imaging), disaggregated by facility, sex and outpatient
visit age band. Additive count only, so it can be aggregated to any period.
{% enddocs %}

{% docs ds__outpatient_visit__age_group %}
Outpatient visit age band at the visit date: '<1 year', '1-4 years', '5-14 years',
'15-49 years', '50+ years', or 'Unknown age' when the birth date is missing, or the
computed age at the visit is negative or greater than 120 (implausible/bad data).
{% enddocs %}

{% docs ds__outpatient_visit__total_outpatient_visits %}
Count of outpatient visits (encounters whose first history segment has OMOP visit concept
9202/Outpatient Visit) in the group.
{% enddocs %}

{% docs ds__outpatient_visit__tupaia_facility_id %}
Tupaia's facility id, mapped from tamanu_facility_id via the deployment's own
tupaia_facility_mapping seed. 'Not available' (never NULL, since this is the data table's
filter column) when the deployment has not configured a facility mapping, or when the
facility has no mapping entry.
{% enddocs %}
