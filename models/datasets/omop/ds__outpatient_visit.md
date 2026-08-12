{% docs ds__outpatient_visit %}
Outpatient visits dataset. One row per day per area with a count of outpatient
visits (encounters whose first history segment has OMOP visit concept 9202/Outpatient
Visit -- clinic, vaccination, or imaging), disaggregated by facility, sex and outpatient
visit age band. Additive count only, so it can be aggregated to any period.
{% enddocs %}

{% docs ds__outpatient_visit__yearmonth %}
The visit's calendar month as `'YYYY-MM'` text (`to_char(visit_detail_start_date, 'YYYY-MM')`).
{% enddocs %}

{% docs ds__outpatient_visit__age_group %}
Outpatient visit age band at the visit date, per the WHO primary age classification's
range boundaries: '0-14 years', '15-24 years', '25-44 years', '45-59 years',
'60-74 years', '75+ years', or 'Unknown age' when the birth date is missing, or the
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
facility has no mapping entry. tamanu_facility_id itself is never NULL here -- a visit
whose location doesn't resolve is excluded from the dataset entirely.
{% enddocs %}
